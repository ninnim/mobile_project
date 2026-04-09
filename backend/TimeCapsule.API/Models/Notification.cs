using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("Notifications")]
public class Notification
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid ActorId { get; set; }
    [Required, MaxLength(50)]
    public string Type { get; set; } = string.Empty; // FriendRequest, FriendAccepted, PostReaction, PostComment, CommentReaction, CapsuleUnlocked, ProfileReaction
    public Guid? ReferenceId { get; set; }
    [Required]
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
    public User Actor { get; set; } = null!;
}
