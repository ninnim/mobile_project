using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("Friendships")]
public class Friendship
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RequesterId { get; set; }
    public Guid AddresseeId { get; set; }
    [Required, MaxLength(20)]
    public string Status { get; set; } = "Pending"; // Pending, Accepted, Declined
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    public User Requester { get; set; } = null!;
    public User Addressee { get; set; } = null!;
}
