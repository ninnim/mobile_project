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
        var preview = dto.MessageType == "Image" ? "📷 Image"
                    : dto.MessageType == "Voice" ? "🎤 Voice message"
                    : dto.Message;
        _ = _fcm.SendChatNotificationAsync(dto.ReceiverId, senderId, senderName, preview);

        return MapToDto(chat);
    }

    public async Task<List<ChatMessageDto>> GetConversationAsync(Guid userId, Guid otherUserId, DateTime? before = null, int limit = 30)
    {
        var query = _db.Chats
            .Include(c => c.Reactions).ThenInclude(r => r.User)
            .Where(c => (c.SenderId == userId && c.ReceiverId == otherUserId) ||
                        (c.SenderId == otherUserId && c.ReceiverId == userId));

        if (before.HasValue)
            query = query.Where(c => c.CreatedAt < before.Value);

        var messages = await query
            .OrderByDescending(c => c.CreatedAt)
            .Take(limit)
            .OrderBy(c => c.CreatedAt)
            .ToListAsync();

        return messages.Select(MapToDto).ToList();
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
                    LastMessage = chat.MessageType == "Voice" ? "🎤 Voice message"
                               : chat.MessageType == "Image" ? "📷 Image"
                               : chat.Message,
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

    public async Task<ChatReactionDto> ReactToMessageAsync(Guid userId, Guid messageId, string reactionType)
    {
        var chat = await _db.Chats.FindAsync(messageId)
            ?? throw new KeyNotFoundException("Message not found.");

        // Ensure user is part of this conversation
        if (chat.SenderId != userId && chat.ReceiverId != userId)
            throw new UnauthorizedAccessException("Cannot react to this message.");

        var existing = await _db.ChatReactions
            .FirstOrDefaultAsync(r => r.ChatId == messageId && r.UserId == userId);

        if (existing != null)
        {
            existing.ReactionType = reactionType;
            existing.CreatedAt = DateTime.UtcNow;
        }
        else
        {
            existing = new ChatReaction
            {
                Id = Guid.NewGuid(),
                ChatId = messageId,
                UserId = userId,
                ReactionType = reactionType,
                CreatedAt = DateTime.UtcNow
            };
            _db.ChatReactions.Add(existing);
        }
        await _db.SaveChangesAsync();

        var user = await _db.Users.FindAsync(userId);
        return new ChatReactionDto
        {
            Id = existing.Id,
            ChatId = messageId,
            UserId = userId,
            DisplayName = user?.DisplayName ?? "",
            ReactionType = reactionType,
            CreatedAt = existing.CreatedAt
        };
    }

    public async Task RemoveReactionAsync(Guid userId, Guid messageId)
    {
        var reaction = await _db.ChatReactions
            .FirstOrDefaultAsync(r => r.ChatId == messageId && r.UserId == userId);
        if (reaction != null)
        {
            _db.ChatReactions.Remove(reaction);
            await _db.SaveChangesAsync();
        }
    }

    private static ChatMessageDto MapToDto(Chat c) => new()
    {
        Id = c.Id, SenderId = c.SenderId, ReceiverId = c.ReceiverId,
        Message = c.Message, IsRead = c.IsRead,
        MessageType = c.MessageType, MediaUrl = c.MediaUrl, Status = c.Status,
        CreatedAt = c.CreatedAt,
        Reactions = c.Reactions?.Select(r => new ChatReactionDto
        {
            Id = r.Id,
            ChatId = r.ChatId,
            UserId = r.UserId,
            DisplayName = r.User?.DisplayName ?? "",
            ReactionType = r.ReactionType,
            CreatedAt = r.CreatedAt
        }).ToList() ?? new()
    };
}
