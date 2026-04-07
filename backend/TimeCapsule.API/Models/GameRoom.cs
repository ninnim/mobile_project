using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("GameRooms")]
public class GameRoom
{
    [Key]
    public Guid Id { get; set; }
    public Guid CreatorId { get; set; }
    [Required, MaxLength(150)]
    public string Title { get; set; } = string.Empty;
    public bool IsPublic { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("CreatorId")]
    public User Creator { get; set; } = null!;
    public ICollection<Capsule> Capsules { get; set; } = new List<Capsule>();
}
