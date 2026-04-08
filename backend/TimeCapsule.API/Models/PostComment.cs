using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("PostComments")]
public class PostComment
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid PostId { get; set; }
    public Guid UserId { get; set; }
    [Required] public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("PostId")] public Post Post { get; set; } = null!;
    [ForeignKey("UserId")] public User User { get; set; } = null!;
    public ICollection<CommentReaction> Reactions { get; set; } = new List<CommentReaction>();
}
