namespace TimeCapsule.API.DTOs.Chat;

public class ChatMessageDto
{
    public Guid Id { get; set; }
    public Guid SenderId { get; set; }
    public Guid ReceiverId { get; set; }
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public string MessageType { get; set; } = "Text";
    public string? MediaUrl { get; set; }
    public string Status { get; set; } = "Sent";
    public DateTime CreatedAt { get; set; }
    public List<ChatReactionDto> Reactions { get; set; } = new();
}
