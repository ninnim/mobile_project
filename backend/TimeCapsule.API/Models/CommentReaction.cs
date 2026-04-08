using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("CommentReactions")]
public class CommentReaction
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid CommentId { get; set; }
    public Guid UserId { get; set; }
    [MaxLength(20)] public string ReactionType { get; set; } = "like";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("CommentId")] public PostComment Comment { get; set; } = null!;
    [ForeignKey("UserId")] public User User { get; set; } = null!;
}
