using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Capsule;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class CapsuleService : ICapsuleService
{
    private readonly AppDbContext _db;
    private readonly IFileUploadService _fileUpload;
    private readonly ILogger<CapsuleService> _logger;

    public CapsuleService(AppDbContext db, IFileUploadService fileUpload, ILogger<CapsuleService> logger)
    {
        _db = db; _fileUpload = fileUpload; _logger = logger;
    }

    public async Task<CapsuleResponseDto> CreateAsync(Guid senderId, CreateCapsuleDto dto)
    {
        if (!new[] { 5, 50 }.Contains(dto.ProximityTolerance))
            throw new ArgumentException("ProximityTolerance must be 5 or 50.");

        var capsule = new Capsule
        {
            Id = Guid.NewGuid(),
            SenderId = senderId,
            Title = dto.Title,
            Message = dto.Message,
            Latitude = (decimal)dto.Latitude,
            Longitude = (decimal)dto.Longitude,
            UnlockDate = dto.UnlockDate.ToUniversalTime(),
            IsPublic = dto.IsPublic,
            GameRoomId = dto.GameRoomId,
            PointsReward = dto.PointsReward,
            ProximityTolerance = dto.ProximityTolerance,
            ReceiverUserId = dto.ReceiverUserId,
            Status = "Locked"
        };

        _db.Capsules.Add(capsule);

        if (dto.MediaFiles != null)
        {
            foreach (var file in dto.MediaFiles.Take(5))
            {
                var url = await _fileUpload.SaveFileAsync(file);
                var isImage = file.ContentType.StartsWith("image/");
                _db.CapsuleMedia.Add(new CapsuleMedia
                {
                    Id = Guid.NewGuid(),
                    CapsuleId = capsule.Id,
                    FileUrl = url,
                    FileType = isImage ? "Image" : "Video"
                });
            }
        }

        await _db.SaveChangesAsync();
        return await GetCapsuleResponseAsync(capsule.Id, senderId);
    }

    public async Task<List<CapsuleResponseDto>> GetMyCapsulesAsync(Guid userId)
    {
        var capsules = await _db.Capsules
            .Include(c => c.Sender)
            .Include(c => c.Media)
            .Where(c => c.SenderId == userId || c.ReceiverUserId == userId)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();
        return capsules.Select(c => MapToDto(c, true)).ToList();
    }

    public async Task<List<CapsuleResponseDto>> GetPublicCapsulesAsync()
    {
        var capsules = await _db.Capsules
            .Include(c => c.Sender)
            .Include(c => c.Media)
            .Where(c => c.IsPublic)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();
        return capsules.Select(c => MapToDto(c, c.Status == "Unlocked")).ToList();
    }

    public async Task<CapsuleResponseDto> GetByIdAsync(Guid id, Guid requestingUserId)
    {
        var capsule = await _db.Capsules
            .Include(c => c.Sender)
            .Include(c => c.Media)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new KeyNotFoundException("Capsule not found.");
        var showMessage = capsule.SenderId == requestingUserId || capsule.Status == "Unlocked";
        return MapToDto(capsule, showMessage);
    }

    public async Task<UnlockResultDto> UnlockAsync(Guid capsuleId, Guid userId, UnlockCapsuleDto dto)
    {
        _logger.LogInformation("Unlock attempt for capsule {CapsuleId} by user {UserId} at ({Lat},{Lon})",
            capsuleId, userId, dto.Latitude, dto.Longitude);

        var capsule = await _db.Capsules
            .Include(c => c.Sender)
            .Include(c => c.Media)
            .FirstOrDefaultAsync(c => c.Id == capsuleId)
            ?? throw new KeyNotFoundException("Capsule not found.");

        if (DateTime.UtcNow < capsule.UnlockDate)
        {
            return new UnlockResultDto
            {
                Success = false,
                Message = $"This capsule cannot be unlocked until {capsule.UnlockDate:yyyy-MM-dd}."
            };
        }

        if (capsule.GameRoomId != null && capsule.Status == "Unlocked")
        {
            return new UnlockResultDto
            {
                Success = false,
                Message = "This capsule has already been claimed by another player."
            };
        }

        var distance = GpsHelper.CalculateDistanceInMeters(
            dto.Latitude, dto.Longitude,
            (double)capsule.Latitude, (double)capsule.Longitude);

        if (distance > capsule.ProximityTolerance)
        {
            return new UnlockResultDto
            {
                Success = false,
                Message = $"You are {distance:F1} meters away. You need to be within {capsule.ProximityTolerance} meters.",
                DistanceMeters = distance
            };
        }

        // Use optimistic concurrency for game room capsules
        if (capsule.GameRoomId != null)
        {
            var rows = await _db.Capsules
                .Where(c => c.Id == capsuleId && c.Status == "Locked")
                .ExecuteUpdateAsync(s => s
                    .SetProperty(c => c.Status, "Unlocked")
                    .SetProperty(c => c.UnlockedByUserId, userId));
            if (rows == 0)
            {
                return new UnlockResultDto
                {
                    Success = false,
                    Message = "This capsule has already been claimed by another player."
                };
            }
            capsule.Status = "Unlocked";
            capsule.UnlockedByUserId = userId;
        }
        else
        {
            capsule.Status = "Unlocked";
            capsule.UnlockedByUserId = userId;
            await _db.SaveChangesAsync();
        }

        return new UnlockResultDto
        {
            Success = true,
            Message = $"Capsule unlocked! You were {distance:F1} meters away.",
            Capsule = MapToDto(capsule, true),
            PointsAwarded = capsule.PointsReward
        };
    }

    public async Task<List<CapsuleResponseDto>> GetByGameRoomAsync(Guid gameRoomId)
    {
        var capsules = await _db.Capsules
            .Include(c => c.Sender)
            .Include(c => c.Media)
            .Where(c => c.GameRoomId == gameRoomId)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();
        return capsules.Select(c => MapToDto(c, c.Status == "Unlocked")).ToList();
    }

    private async Task<CapsuleResponseDto> GetCapsuleResponseAsync(Guid capsuleId, Guid requestingUserId)
    {
        var capsule = await _db.Capsules
            .Include(c => c.Sender)
            .Include(c => c.Media)
            .FirstAsync(c => c.Id == capsuleId);
        return MapToDto(capsule, true);
    }

    private static CapsuleResponseDto MapToDto(Capsule c, bool includeMessage) => new()
    {
        Id = c.Id, SenderId = c.SenderId, SenderName = c.Sender?.DisplayName ?? "",
        Title = c.Title, Message = includeMessage ? c.Message : null,
        Latitude = (double)c.Latitude, Longitude = (double)c.Longitude,
        UnlockDate = c.UnlockDate, IsPublic = c.IsPublic, Status = c.Status,
        GameRoomId = c.GameRoomId, ReceiverUserId = c.ReceiverUserId,
        PointsReward = c.PointsReward, ProximityTolerance = c.ProximityTolerance,
        Media = c.Media.Select(m => new CapsuleMediaDto { Id = m.Id, FileUrl = m.FileUrl, FileType = m.FileType }).ToList(),
        CreatedAt = c.CreatedAt
    };
}
