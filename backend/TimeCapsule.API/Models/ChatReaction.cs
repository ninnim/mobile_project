using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("ChatReactions")]
public class ChatReaction
{
    [Key]
    public Guid Id { get; set; }
    public Guid ChatId { get; set; }
    public Guid UserId { get; set; }
    [MaxLength(20)]
    public string ReactionType { get; set; } = "like";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("ChatId")]
    public Chat Chat { get; set; } = null!;
    [ForeignKey("UserId")]
    public User User { get; set; } = null!;
}
