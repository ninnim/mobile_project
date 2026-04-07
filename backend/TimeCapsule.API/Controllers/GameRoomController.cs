using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.GameRoom;
using TimeCapsule.API.Services;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/gamerooms")]
[Authorize]
public class GameRoomController : ControllerBase
{
    private readonly IGameRoomService _rooms;
    private readonly AppDbContext _db;
    public GameRoomController(IGameRoomService rooms, AppDbContext db) { _rooms = rooms; _db = db; }
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateGameRoomDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        return StatusCode(201, await _rooms.CreateAsync(UserId, dto));
    }

    [HttpGet]
    public async Task<IActionResult> GetPublic() => Ok(await _rooms.GetPublicAsync());

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        try { return Ok(await _rooms.GetByIdAsync(id)); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [HttpGet("my")]
    public async Task<IActionResult> GetMy() => Ok(await _rooms.GetMyAsync(UserId));

    [HttpGet("{id:guid}/leaderboard")]
    public async Task<IActionResult> GetLeaderboard(Guid id)
    {
        var capsules = await _db.Capsules
            .Include(c => c.UnlockedByUser)
            .Where(c => c.GameRoomId == id && c.Status == "Unlocked" && c.UnlockedByUserId != null)
            .ToListAsync();

        var leaderboard = capsules
            .GroupBy(c => c.UnlockedByUserId!.Value)
            .Select(g => new LeaderboardEntryDto
            {
                UserId = g.Key,
                DisplayName = g.First().UnlockedByUser?.DisplayName ?? "Unknown",
                ProfilePictureUrl = g.First().UnlockedByUser?.ProfilePictureUrl,
                TotalPoints = g.Sum(c => c.PointsReward),
                UnlockedCount = g.Count(),
            })
            .OrderByDescending(e => e.TotalPoints)
            .ThenByDescending(e => e.UnlockedCount)
            .ToList();

        for (int i = 0; i < leaderboard.Count; i++)
            leaderboard[i].Rank = i + 1;

        return Ok(leaderboard);
    }
}
