using TimeCapsule.API.DTOs.Chat;

namespace TimeCapsule.API.Services;

public interface IChatService
{
    Task<ChatMessageDto> SendAsync(Guid senderId, SendMessageDto dto);
    Task<List<ChatMessageDto>> GetConversationAsync(Guid userId, Guid otherUserId, DateTime? before = null, int limit = 30);
    Task<List<ContactDto>> GetContactsAsync(Guid userId);
    Task MarkAsReadAsync(Guid userId, Guid otherUserId);
    Task MarkAsDeliveredAsync(Guid userId, Guid otherUserId);
}
