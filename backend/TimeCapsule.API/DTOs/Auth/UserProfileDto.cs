namespace TimeCapsule.API.DTOs.Auth;

public class UserProfileDto
{
    public Guid Id { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? ProfilePictureUrl { get; set; }
    public string? Bio { get; set; }
    public string? AccentColor { get; set; }
    public DateTime CreatedAt { get; set; }
    public int CapsuleCount { get; set; }
    public int PostCount { get; set; }
}

public class UpdateProfileDto
{
    public string? DisplayName { get; set; }
    public string? ProfilePictureUrl { get; set; }
    public string? Bio { get; set; }
    public string? AccentColor { get; set; }
}
