using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("Users")]
public class User
{
    [Key]
    public Guid Id { get; set; }
    [Required, MaxLength(255)]
    public string Email { get; set; } = string.Empty;
    [MaxLength(255)]
    public string? PasswordHash { get; set; }
    [Required, MaxLength(100)]
    public string DisplayName { get; set; } = string.Empty;
    [MaxLength(500)]
    public string? ProfilePictureUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    [MaxLength(255)]
    public string? GoogleId { get; set; }
    [MaxLength(255)]
    public string? FacebookId { get; set; }
    [MaxLength(50)]
    public string AuthProvider { get; set; } = "Email";

    [MaxLength(300)]
    public string? Bio { get; set; }
    [MaxLength(20)]
    public string? AccentColor { get; set; } = "#00E5FF";

    [MaxLength(500)]
    public string? FcmToken { get; set; }

    public bool IsOnline { get; set; } = false;
    public DateTime LastSeen { get; set; } = DateTime.UtcNow;

    public ICollection<Capsule> Capsules { get; set; } = new List<Capsule>();
    public ICollection<GameRoom> GameRooms { get; set; } = new List<GameRoom>();
    public ICollection<Chat> SentChats { get; set; } = new List<Chat>();
    public ICollection<Chat> ReceivedChats { get; set; } = new List<Chat>();
    public ICollection<Post> Posts { get; set; } = new List<Post>();
    public ICollection<TripAnalysis> TripAnalyses { get; set; } = new List<TripAnalysis>();
    public ICollection<PasswordResetToken> PasswordResetTokens { get; set; } = new List<PasswordResetToken>();
    public ICollection<Friendship> SentFriendRequests { get; set; } = new List<Friendship>();
    public ICollection<Friendship> ReceivedFriendRequests { get; set; } = new List<Friendship>();
}
