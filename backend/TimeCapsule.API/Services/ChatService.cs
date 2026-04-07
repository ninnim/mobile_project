using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Chat;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class ChatService : IChatService
{
    private readonly AppDbContext _db;
    private readonly ILogger<ChatService> _logger;
    private readonly IFileUploadService _fileUpload;
    private readonly IFcmNotificationService _fcm;

    public ChatService(AppDbContext db, ILogger<ChatService> logger, IFileUploadService fileUpload, IFcmNotificationService fcm)
    { _db = db; _logger = logger; _fileUpload = fileUpload; _fcm = fcm; }

    public async Task<ChatMessageDto> SendAsync(Guid senderId, SendMessageDto dto)
    {
        var receiverExists = await _db.Users.AnyAsync(u => u.Id == dto.ReceiverId);
        if (!receiverExists) throw new KeyNotFoundException("Receiver not found.");

        string? mediaUrl = null;
        if (dto.MediaFile != null)
            mediaUrl = await _fileUpload.SaveFileAsync(dto.MediaFile);

        var chat = new Chat
        {
            Id = Guid.NewGuid(), SenderId = senderId, ReceiverId = dto.ReceiverId,
            Message = dto.Message, CreatedAt = DateTime.UtcNow,
            MessageType = dto.MessageType, MediaUrl = mediaUrl, Status = "Sent"
        };
        _db.Chats.Add(chat);
        await _db.SaveChangesAsync();

        // Fire-and-forget push notification; don't block the API response.
        var sender = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == senderId);
        var senderName = sender?.DisplayName ?? "Someone";
        var preview = dto.MessageType == "Image" ? "📷 Image" : dto.Message;
        _ = _fcm.SendChatNotificationAsync(dto.ReceiverId, senderName, preview);

        return MapToDto(chat);
    }

    public async Task<List<ChatMessageDto>> GetConversationAsync(Guid userId, Guid otherUserId, DateTime? before = null, int limit = 30)
    {
        var query = _db.Chats
            .Where(c => (c.SenderId == userId && c.ReceiverId == otherUserId) ||
                        (c.SenderId == otherUserId && c.ReceiverId == userId));

        if (before.HasValue)
            query = query.Where(c => c.CreatedAt < before.Value);

        return await query
            .OrderByDescending(c => c.CreatedAt)
            .Take(limit)
            .OrderBy(c => c.CreatedAt) // re-order ascending for display
            .Select(c => MapToDto(c))
            .ToListAsync();
    }

    public async Task<List<ContactDto>> GetContactsAsync(Guid userId)
    {
        var chats = await _db.Chats
            .Include(c => c.Sender)
            .Include(c => c.Receiver)
            .Where(c => c.SenderId == userId || c.ReceiverId == userId)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();

        var contactMap = new Dictionary<Guid, ContactDto>();
        foreach (var chat in chats)
        {
            var otherId = chat.SenderId == userId ? chat.ReceiverId : chat.SenderId;
            var otherUser = chat.SenderId == userId ? chat.Receiver : chat.Sender;
            if (!contactMap.ContainsKey(otherId))
            {
                contactMap[otherId] = new ContactDto
                {
                    UserId = otherId,
                    DisplayName = otherUser?.DisplayName ?? "",
                    ProfilePictureUrl = otherUser?.ProfilePictureUrl,
                    LastMessage = chat.Message,
                    LastMessageAt = chat.CreatedAt,
                    UnreadCount = 0
                };
            }
            if (chat.ReceiverId == userId && !chat.IsRead)
                contactMap[otherId].UnreadCount++;
        }
        return contactMap.Values.ToList();
    }

    public async Task MarkAsReadAsync(Guid userId, Guid otherUserId)
    {
        await _db.Chats
            .Where(c => c.SenderId == otherUserId && c.ReceiverId == userId && !c.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.IsRead, true)
                                      .SetProperty(c => c.Status, "Read"));
    }

    public async Task MarkAsDeliveredAsync(Guid userId, Guid otherUserId)
    {
        await _db.Chats
            .Where(c => c.SenderId == otherUserId && c.ReceiverId == userId && c.Status == "Sent")
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.Status, "Delivered"));
    }

    private static ChatMessageDto MapToDto(Chat c) => new()
    {
        Id = c.Id, SenderId = c.SenderId, ReceiverId = c.ReceiverId,
        Message = c.Message, IsRead = c.IsRead,
        MessageType = c.MessageType, MediaUrl = c.MediaUrl, Status = c.Status,
        CreatedAt = c.CreatedAt
    };
}
