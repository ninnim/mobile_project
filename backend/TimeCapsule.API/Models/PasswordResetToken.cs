using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("PasswordResetTokens")]
public class PasswordResetToken
{
    [Key]
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    [Required, MaxLength(128)]
    public string Token { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public DateTime? UsedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}
