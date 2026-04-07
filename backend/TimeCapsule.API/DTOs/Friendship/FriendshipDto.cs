namespace TimeCapsule.API.DTOs.Friendship;

public class FriendDto
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = "";
    public string? ProfilePictureUrl { get; set; }
    public string Status { get; set; } = ""; // Accepted, Pending
    public bool IsRequester { get; set; } // true if current user sent the request
    public DateTime CreatedAt { get; set; }
}

public class UserSearchDto
{
    public Guid Id { get; set; }
    public string DisplayName { get; set; } = "";
    public string Email { get; set; } = "";
    public string? ProfilePictureUrl { get; set; }
    public string FriendshipStatus { get; set; } = "None"; // None, Pending, Accepted, Requested (they sent to you)
}
