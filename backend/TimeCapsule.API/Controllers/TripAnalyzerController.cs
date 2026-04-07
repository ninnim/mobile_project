using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TimeCapsule.API.DTOs.Trip;
using TimeCapsule.API.Services;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/trip-analyzer")]
[Authorize]
public class TripAnalyzerController : ControllerBase
{
    private readonly ITripAnalyzerService _trips;
    public TripAnalyzerController(ITripAnalyzerService trips) { _trips = trips; }
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpPost("analyze")]
    public async Task<IActionResult> Analyze([FromBody] TripRequestDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        return StatusCode(201, await _trips.AnalyzeAsync(UserId, dto));
    }

    [HttpGet("history")]
    public async Task<IActionResult> GetHistory() => Ok(await _trips.GetHistoryAsync(UserId));
}
