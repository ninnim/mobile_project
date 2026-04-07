using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Capsule;
using TimeCapsule.API.DTOs.GameRoom;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class GameRoomService : IGameRoomService
{
    private readonly AppDbContext _db;
    public GameRoomService(AppDbContext db) { _db = db; }

    public async Task<GameRoomResponseDto> CreateAsync(Guid creatorId, CreateGameRoomDto dto)
    {
        var room = new GameRoom
        {
            Id = Guid.NewGuid(), CreatorId = creatorId,
            Title = dto.Title, IsPublic = dto.IsPublic, CreatedAt = DateTime.UtcNow
        };
        _db.GameRooms.Add(room);
        await _db.SaveChangesAsync();
        var creator = await _db.Users.FindAsync(creatorId);
        return MapToDto(room, creator, null);
    }

    public async Task<List<GameRoomResponseDto>> GetPublicAsync()
    {
        var rooms = await _db.GameRooms
            .Include(r => r.Creator)
            .Include(r => r.Capsules)
            .Where(r => r.IsPublic)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync();
        return rooms.Select(r => MapToDto(r, r.Creator, null)).ToList();
    }

    public async Task<GameRoomResponseDto> GetByIdAsync(Guid id)
    {
        var room = await _db.GameRooms
            .Include(r => r.Creator)
            .Include(r => r.Capsules).ThenInclude(c => c.Sender)
            .Include(r => r.Capsules).ThenInclude(c => c.Media)
            .FirstOrDefaultAsync(r => r.Id == id)
            ?? throw new KeyNotFoundException("Game room not found.");

        var capsuleDtos = room.Capsules.Select(c => new CapsuleResponseDto
        {
            Id = c.Id, SenderId = c.SenderId, SenderName = c.Sender?.DisplayName ?? "",
            Title = c.Title, Message = c.Status == "Unlocked" ? c.Message : null,
            Latitude = (double)c.Latitude, Longitude = (double)c.Longitude,
            UnlockDate = c.UnlockDate, IsPublic = c.IsPublic, Status = c.Status,
            GameRoomId = c.GameRoomId, PointsReward = c.PointsReward, ProximityTolerance = c.ProximityTolerance,
            Media = c.Media.Select(m => new CapsuleMediaDto { Id = m.Id, FileUrl = m.FileUrl, FileType = m.FileType }).ToList(),
            CreatedAt = c.CreatedAt
        }).ToList();

        return MapToDto(room, room.Creator, capsuleDtos);
    }

    public async Task<List<GameRoomResponseDto>> GetMyAsync(Guid userId)
    {
        var rooms = await _db.GameRooms
            .Include(r => r.Creator)
            .Include(r => r.Capsules)
            .Where(r => r.CreatorId == userId)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync();
        return rooms.Select(r => MapToDto(r, r.Creator, null)).ToList();
    }

    private static GameRoomResponseDto MapToDto(GameRoom r, User? creator, List<CapsuleResponseDto>? capsules) => new()
    {
        Id = r.Id, CreatorId = r.CreatorId, CreatorName = creator?.DisplayName ?? "",
        Title = r.Title, IsPublic = r.IsPublic, CapsuleCount = r.Capsules?.Count ?? 0,
        CreatedAt = r.CreatedAt, Capsules = capsules
    };
}
