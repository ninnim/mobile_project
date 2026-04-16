using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Spin;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/spin")]
[Authorize]
public class SpinController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly ILogger<SpinController> _logger;

    // 8 wheel segments — must match the Flutter wheel segment order exactly
    private static readonly (string Name, int Points, int Weight)[] Segments =
    [
        ("100 Points",  100, 20),
        ("Free Spin",    50, 15),
        ("200 Points",  200, 12),
        ("No Luck",       0, 18),
        ("150 Points",  150, 14),
        ("25 Points",    25, 13),
        ("JACKPOT!",    500,  3),
        ("75 Points",    75, 15),
    ];

    public SpinController(AppDbContext db, ILogger<SpinController> logger)
    {
        _db = db;
        _logger = logger;
    }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpPost]
    public async Task<IActionResult> Spin()
    {
        var user = await _db.Users.FindAsync(UserId);
        if (user == null) return NotFound(new { error = "User not found." });

        const int spinCost = 50;
        if (user.PointsBalance < spinCost)
            return BadRequest(new { error = $"Not enough points. You need {spinCost} points to spin." });

        // Weighted random prize selection
        var totalWeight = Segments.Sum(s => s.Weight);
        var roll = Random.Shared.Next(totalWeight);
        var cumulative = 0;
        var segmentIndex = 0;
        for (var i = 0; i < Segments.Length; i++)
        {
            cumulative += Segments[i].Weight;
            if (roll < cumulative)
            {
                segmentIndex = i;
                break;
            }
        }

        var (prizeName, pointsWon, _) = Segments[segmentIndex];
        user.PointsBalance = user.PointsBalance - spinCost + pointsWon;
        await _db.SaveChangesAsync();

        _logger.LogInformation("User {UserId} spun the wheel: segment {Segment}, won {Points} pts, new balance {Balance}",
            UserId, prizeName, pointsWon, user.PointsBalance);

        return Ok(new SpinResponseDto
        {
            PrizeName = prizeName,
            PointsWon = pointsWon,
            NewBalance = user.PointsBalance,
            SegmentIndex = segmentIndex
        });
    }
}
