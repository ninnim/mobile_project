using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("PostReactions")]
public class PostReaction
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid PostId { get; set; }
    public Guid UserId { get; set; }
    [MaxLength(20)]
    public string ReactionType { get; set; } = "like"; // like, love, haha, wow, sad, angry
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("PostId")] public Post Post { get; set; } = null!;
    [ForeignKey("UserId")] public User User { get; set; } = null!;
}
