using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("ProfileReactions")]
public class ProfileReaction
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ProfileUserId { get; set; }
    public Guid ReactorUserId { get; set; }
    [MaxLength(20)] public string ReactionType { get; set; } = "like";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("ProfileUserId")] public User ProfileUser { get; set; } = null!;
    [ForeignKey("ReactorUserId")] public User Reactor { get; set; } = null!;
}
