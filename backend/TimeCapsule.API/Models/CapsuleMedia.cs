using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("CapsuleMedia")]
public class CapsuleMedia
{
    [Key]
    public Guid Id { get; set; }
    public Guid CapsuleId { get; set; }
    [Required, MaxLength(500)]
    public string FileUrl { get; set; } = string.Empty;
    [MaxLength(50)]
    public string? FileType { get; set; }

    [ForeignKey("CapsuleId")]
    public Capsule Capsule { get; set; } = null!;
}
