using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Trip;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class TripAnalyzerService : ITripAnalyzerService
{
    private readonly AppDbContext _db;
    private readonly ILogger<TripAnalyzerService> _logger;

    public TripAnalyzerService(AppDbContext db, ILogger<TripAnalyzerService> logger)
    { _db = db; _logger = logger; }

    public async Task<TripResponseDto> AnalyzeAsync(Guid userId, TripRequestDto dto)
    {
        var dailyBudget = dto.TotalBudget / dto.NumberOfDays;
        string? warning = null;
        bool sufficient = true;
        if (dailyBudget < 30) { warning = $"Your budget is extremely tight for {dto.Destination}"; sufficient = false; }
        else if (dailyBudget < 50) { warning = "Budget is tight. Consider reducing activities."; sufficient = false; }

        var days = GenerateDayPlans(dto.Destination, dto.NumberOfDays, dailyBudget);

        var response = new TripResponseDto
        {
            Id = Guid.NewGuid(), Destination = dto.Destination,
            NumberOfDays = dto.NumberOfDays, TotalBudget = dto.TotalBudget,
            DailyBudget = dailyBudget, IsBudgetSufficient = sufficient,
            Warning = warning, Days = days, CreatedAt = DateTime.UtcNow
        };

        var entity = new TripAnalysis
        {
            Id = response.Id, UserId = userId, Destination = dto.Destination,
            NumberOfDays = dto.NumberOfDays, TotalBudget = dto.TotalBudget,
            AIResponseJson = JsonSerializer.Serialize(response), CreatedAt = response.CreatedAt
        };
        _db.TripAnalyses.Add(entity);
        await _db.SaveChangesAsync();
        return response;
    }

    public async Task<List<TripResponseDto>> GetHistoryAsync(Guid userId)
    {
        var analyses = await _db.TripAnalyses
            .Where(t => t.UserId == userId)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();
        return analyses.Select(a =>
        {
            if (!string.IsNullOrEmpty(a.AIResponseJson))
            {
                var r = JsonSerializer.Deserialize<TripResponseDto>(a.AIResponseJson);
                if (r != null) return r;
            }
            return new TripResponseDto { Id = a.Id, Destination = a.Destination, NumberOfDays = a.NumberOfDays, TotalBudget = a.TotalBudget, CreatedAt = a.CreatedAt };
        }).ToList();
    }

    private static List<DayPlanDto> GenerateDayPlans(string destination, int days, decimal dailyBudget)
    {
        var dest = destination.Trim().ToLower();
        var plans = new List<DayPlanDto>();

        var destData = GetDestinationData(dest, destination);
        for (int i = 1; i <= days; i++)
        {
            var dayIndex = (i - 1) % destData.DayThemes.Count;
            plans.Add(new DayPlanDto
            {
                Day = i,
                Theme = destData.DayThemes[dayIndex],
                Budget = dailyBudget,
                Activities = destData.DayActivities[dayIndex].ToList(),
                RecommendedSpots = destData.DaySpots[dayIndex].ToList()
            });
        }
        return plans;
    }

    private static DestinationData GetDestinationData(string destLower, string destDisplay)
    {
        return destLower switch
        {
            "paris" => new DestinationData(
                new[] { "Arrival & Iconic Landmarks", "Art & Culture", "Hidden Gems" },
                new[] {
                    new[] { "Visit Eiffel Tower", "Lunch at local café", "Seine River cruise" },
                    new[] { "Explore the Louvre", "Stroll through Montmartre", "Visit Sacré-Cœur" },
                    new[] { "Walk Champs-Élysées", "Visit Musée d'Orsay", "Evening at Le Marais" }
                },
                new[] {
                    new[] { new RecommendedSpotDto { Name="Eiffel Tower", Type="Landmark", EstimatedCost=25 }, new RecommendedSpotDto { Name="Bateaux Mouches", Type="Activity", EstimatedCost=15 }, new RecommendedSpotDto { Name="Café de Flore", Type="Restaurant", EstimatedCost=35 } },
                    new[] { new RecommendedSpotDto { Name="The Louvre", Type="Museum", EstimatedCost=17 }, new RecommendedSpotDto { Name="Montmartre", Type="Neighborhood", EstimatedCost=0 }, new RecommendedSpotDto { Name="Sacré-Cœur", Type="Landmark", EstimatedCost=0 } },
                    new[] { new RecommendedSpotDto { Name="Champs-Élysées", Type="Street", EstimatedCost=0 }, new RecommendedSpotDto { Name="Musée d'Orsay", Type="Museum", EstimatedCost=16 }, new RecommendedSpotDto { Name="Le Marais", Type="Neighborhood", EstimatedCost=0 } }
                }),
            "tokyo" => new DestinationData(
                new[] { "Modern Tokyo", "Traditional Culture", "Pop Culture & Food" },
                new[] {
                    new[] { "Explore Shibuya Crossing", "Visit Shibuya Sky", "Evening at Shinjuku" },
                    new[] { "Visit Senso-ji Temple", "Explore Asakusa", "Traditional tea ceremony" },
                    new[] { "Anime shops in Akihabara", "Tsukiji outer market breakfast", "Day trip to Mt. Fuji" }
                },
                new[] {
                    new[] { new RecommendedSpotDto { Name="Shibuya Crossing", Type="Landmark", EstimatedCost=0 }, new RecommendedSpotDto { Name="Shibuya Sky", Type="Observation Deck", EstimatedCost=20 }, new RecommendedSpotDto { Name="Shinjuku", Type="Neighborhood", EstimatedCost=0 } },
                    new[] { new RecommendedSpotDto { Name="Senso-ji", Type="Temple", EstimatedCost=0 }, new RecommendedSpotDto { Name="Asakusa", Type="Neighborhood", EstimatedCost=0 }, new RecommendedSpotDto { Name="Tea Ceremony", Type="Activity", EstimatedCost=30 } },
                    new[] { new RecommendedSpotDto { Name="Akihabara", Type="Neighborhood", EstimatedCost=0 }, new RecommendedSpotDto { Name="Tsukiji Market", Type="Market", EstimatedCost=20 }, new RecommendedSpotDto { Name="Mt. Fuji", Type="Landmark", EstimatedCost=25 } }
                }),
            "new york" or "new york city" or "nyc" => new DestinationData(
                new[] { "Manhattan Highlights", "Arts & Boroughs", "Classic NYC" },
                new[] {
                    new[] { "Walk Central Park", "Times Square experience", "High Line stroll" },
                    new[] { "Brooklyn Bridge walk", "Visit MoMA", "Chelsea Market food tour" },
                    new[] { "Statue of Liberty ferry", "Wall Street & 9/11 Memorial", "Broadway show" }
                },
                new[] {
                    new[] { new RecommendedSpotDto { Name="Central Park", Type="Park", EstimatedCost=0 }, new RecommendedSpotDto { Name="Times Square", Type="Landmark", EstimatedCost=0 }, new RecommendedSpotDto { Name="High Line", Type="Park", EstimatedCost=0 } },
                    new[] { new RecommendedSpotDto { Name="Brooklyn Bridge", Type="Landmark", EstimatedCost=0 }, new RecommendedSpotDto { Name="MoMA", Type="Museum", EstimatedCost=25 }, new RecommendedSpotDto { Name="Chelsea Market", Type="Market", EstimatedCost=30 } },
                    new[] { new RecommendedSpotDto { Name="Statue of Liberty", Type="Landmark", EstimatedCost=24 }, new RecommendedSpotDto { Name="9/11 Memorial", Type="Memorial", EstimatedCost=0 }, new RecommendedSpotDto { Name="Broadway", Type="Entertainment", EstimatedCost=120 } }
                }),
            "london" => new DestinationData(
                new[] { "Royal London", "Arts & Markets", "Hidden London" },
                new[] {
                    new[] { "Big Ben & Westminster", "Buckingham Palace", "St. James's Park" },
                    new[] { "Tower Bridge & Tower of London", "British Museum", "Camden Market" },
                    new[] { "Hyde Park morning", "Notting Hill stroll", "Thames riverside walk" }
                },
                new[] {
                    new[] { new RecommendedSpotDto { Name="Big Ben", Type="Landmark", EstimatedCost=0 }, new RecommendedSpotDto { Name="Buckingham Palace", Type="Landmark", EstimatedCost=0 }, new RecommendedSpotDto { Name="St. James's Park", Type="Park", EstimatedCost=0 } },
                    new[] { new RecommendedSpotDto { Name="Tower Bridge", Type="Landmark", EstimatedCost=12 }, new RecommendedSpotDto { Name="British Museum", Type="Museum", EstimatedCost=0 }, new RecommendedSpotDto { Name="Camden Market", Type="Market", EstimatedCost=0 } },
                    new[] { new RecommendedSpotDto { Name="Hyde Park", Type="Park", EstimatedCost=0 }, new RecommendedSpotDto { Name="Notting Hill", Type="Neighborhood", EstimatedCost=0 }, new RecommendedSpotDto { Name="Thames Walk", Type="Activity", EstimatedCost=0 } }
                }),
            "bangkok" => new DestinationData(
                new[] { "Temples & Palaces", "Markets & Canals", "Street Food & Nightlife" },
                new[] {
                    new[] { "Grand Palace visit", "Wat Pho temple", "Wat Arun sunset" },
                    new[] { "Chatuchak Weekend Market", "Floating market tour", "Khlong Saen Saep canal boat" },
                    new[] { "Khao San Road", "Street food on Yaowarat", "Rooftop bar experience" }
                },
                new[] {
                    new[] { new RecommendedSpotDto { Name="Grand Palace", Type="Landmark", EstimatedCost=15 }, new RecommendedSpotDto { Name="Wat Pho", Type="Temple", EstimatedCost=5 }, new RecommendedSpotDto { Name="Wat Arun", Type="Temple", EstimatedCost=5 } },
                    new[] { new RecommendedSpotDto { Name="Chatuchak Market", Type="Market", EstimatedCost=0 }, new RecommendedSpotDto { Name="Floating Market", Type="Market", EstimatedCost=20 }, new RecommendedSpotDto { Name="Canal Boat", Type="Transport", EstimatedCost=3 } },
                    new[] { new RecommendedSpotDto { Name="Khao San Road", Type="Street", EstimatedCost=0 }, new RecommendedSpotDto { Name="Yaowarat", Type="Neighborhood", EstimatedCost=0 }, new RecommendedSpotDto { Name="Rooftop Bar", Type="Entertainment", EstimatedCost=30 } }
                }),
            _ => new DestinationData(
                new[] { $"Explore {destDisplay}", $"Culture & History of {destDisplay}", $"Local Life in {destDisplay}" },
                new[] {
                    new[] { "Arrive and explore city center", "Visit main landmark", "Welcome dinner at local restaurant" },
                    new[] { "Visit local museum", "Historical district walk", "Traditional cultural experience" },
                    new[] { "Local market visit", "Scenic viewpoint", "Farewell dinner" }
                },
                new[] {
                    new[] { new RecommendedSpotDto { Name=$"{destDisplay} City Center", Type="Landmark", EstimatedCost=0 }, new RecommendedSpotDto { Name="Main Landmark", Type="Landmark", EstimatedCost=15 }, new RecommendedSpotDto { Name="Local Restaurant", Type="Restaurant", EstimatedCost=25 } },
                    new[] { new RecommendedSpotDto { Name="Local Museum", Type="Museum", EstimatedCost=10 }, new RecommendedSpotDto { Name="Historical District", Type="Neighborhood", EstimatedCost=0 }, new RecommendedSpotDto { Name="Cultural Center", Type="Activity", EstimatedCost=20 } },
                    new[] { new RecommendedSpotDto { Name="Local Market", Type="Market", EstimatedCost=0 }, new RecommendedSpotDto { Name="Scenic Viewpoint", Type="Landmark", EstimatedCost=0 }, new RecommendedSpotDto { Name="Farewell Dinner", Type="Restaurant", EstimatedCost=35 } }
                })
        };
    }

    private record DestinationData(
        IList<string> DayThemes,
        IList<string[]> DayActivities,
        IList<RecommendedSpotDto[]> DaySpots);
}
