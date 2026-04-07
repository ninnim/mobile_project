using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("Capsules")]
public class Capsule
{
    [Key]
    public Guid Id { get; set; }
    public Guid SenderId { get; set; }
    [Required, MaxLength(150)]
    public string Title { get; set; } = string.Empty;
    [Required]
    public string Message { get; set; } = string.Empty;
    [Column(TypeName = "decimal(9,6)")]
    public decimal Latitude { get; set; }
    [Column(TypeName = "decimal(9,6)")]
    public decimal Longitude { get; set; }
    public DateTime UnlockDate { get; set; }
    public bool IsPublic { get; set; } = false;
    [MaxLength(20)]
    public string Status { get; set; } = "Locked";
    public Guid? GameRoomId { get; set; }
    public int PointsReward { get; set; } = 0;
    public int ProximityTolerance { get; set; } = 50;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Guid? UnlockedByUserId { get; set; }
    public Guid? ReceiverUserId { get; set; }

    [ForeignKey("SenderId")]
    public User Sender { get; set; } = null!;
    [ForeignKey("GameRoomId")]
    public GameRoom? GameRoom { get; set; }
    [ForeignKey("UnlockedByUserId")]
    public User? UnlockedByUser { get; set; }
    public ICollection<CapsuleMedia> Media { get; set; } = new List<CapsuleMedia>();
}
