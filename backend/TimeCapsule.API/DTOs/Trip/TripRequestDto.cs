using System.ComponentModel.DataAnnotations;

namespace TimeCapsule.API.DTOs.Trip;

public class TripRequestDto
{
    [Required, MaxLength(150)]
    public string Destination { get; set; } = string.Empty;
    [Required, Range(1, 30)]
    public int NumberOfDays { get; set; }
    [Required, Range(0.01, double.MaxValue)]
    public decimal TotalBudget { get; set; }
}
