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

    [ForeignKey("UserId")]
    public User User { get; set; } = null!;

    public ICollection<PostLike> Likes { get; set; } = new List<PostLike>();
    public ICollection<PostComment> Comments { get; set; } = new List<PostComment>();
    public ICollection<PostTag> Tags { get; set; } = new List<PostTag>();
}
