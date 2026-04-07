namespace TimeCapsule.API.DTOs.Trip;

public class TripResponseDto
{
    public Guid Id { get; set; }
    public string Destination { get; set; } = string.Empty;
    public int NumberOfDays { get; set; }
    public decimal TotalBudget { get; set; }
    public decimal DailyBudget { get; set; }
    public bool IsBudgetSufficient { get; set; }
    public string? Warning { get; set; }
    public List<DayPlanDto> Days { get; set; } = new();
    public DateTime CreatedAt { get; set; }
}

public class DayPlanDto
{
    public int Day { get; set; }
    public string Theme { get; set; } = string.Empty;
    public decimal Budget { get; set; }
    public List<string> Activities { get; set; } = new();
    public List<RecommendedSpotDto> RecommendedSpots { get; set; } = new();
}

public class RecommendedSpotDto
{
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public decimal EstimatedCost { get; set; }
}
