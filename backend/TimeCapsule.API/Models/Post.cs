using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("Posts")]
public class Post
{
    [Key]
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    [Required]
    public string Content { get; set; } = string.Empty;
    [MaxLength(500)]
    public string? MediaUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Reference to the original post when this is a share</summary>
    public Guid? SharedPostId { get; set; }

    [ForeignKey("UserId")]
    public User User { get; set; } = null!;

    [ForeignKey("SharedPostId")]
    public Post? SharedPost { get; set; }

    public ICollection<PostLike> Likes { get; set; } = new List<PostLike>();
    public ICollection<PostReaction> Reactions { get; set; } = new List<PostReaction>();
    public ICollection<PostComment> Comments { get; set; } = new List<PostComment>();
    public ICollection<PostTag> Tags { get; set; } = new List<PostTag>();
}
