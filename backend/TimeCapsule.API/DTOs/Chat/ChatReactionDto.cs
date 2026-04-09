namespace TimeCapsule.API.DTOs.Chat;

public class ChatReactionDto
{
    public Guid Id { get; set; }
    public Guid ChatId { get; set; }
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string ReactionType { get; set; } = "like";
    public DateTime CreatedAt { get; set; }
}

public class ReactToMessageDto
{
    public string ReactionType { get; set; } = "like";
}
