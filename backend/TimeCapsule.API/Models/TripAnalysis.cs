using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("TripAnalyses")]
public class TripAnalysis
{
    [Key]
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    [Required, MaxLength(150)]
    public string Destination { get; set; } = string.Empty;
    public int NumberOfDays { get; set; }
    [Column(TypeName = "decimal(10,2)")]
    public decimal TotalBudget { get; set; }
    public string? AIResponseJson { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("UserId")]
    public User User { get; set; } = null!;
}
