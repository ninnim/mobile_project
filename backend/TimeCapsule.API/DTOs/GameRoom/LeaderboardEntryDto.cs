namespace TimeCapsule.API.DTOs.GameRoom;

public class LeaderboardEntryDto
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string? ProfilePictureUrl { get; set; }
    public int TotalPoints { get; set; }
    public int UnlockedCount { get; set; }
    public int Rank { get; set; }
}
