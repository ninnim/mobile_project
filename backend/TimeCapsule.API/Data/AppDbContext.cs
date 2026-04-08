using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users { get; set; }
    public DbSet<GameRoom> GameRooms { get; set; }
    public DbSet<Capsule> Capsules { get; set; }
    public DbSet<CapsuleMedia> CapsuleMedia { get; set; }
    public DbSet<Chat> Chats { get; set; }
    public DbSet<Post> Posts { get; set; }
    public DbSet<TripAnalysis> TripAnalyses { get; set; }
    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<PostLike> PostLikes => Set<PostLike>();
    public DbSet<PostComment> PostComments => Set<PostComment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<CapsuleMedia>()
            .HasOne(cm => cm.Capsule)
            .WithMany(c => c.Media)
            .HasForeignKey(cm => cm.CapsuleId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Chat>()
            .HasOne(c => c.Sender)
            .WithMany(u => u.SentChats)
            .HasForeignKey(c => c.SenderId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Chat>()
            .HasOne(c => c.Receiver)
            .WithMany(u => u.ReceivedChats)
            .HasForeignKey(c => c.ReceiverId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Capsule>()
            .HasOne(c => c.Sender)
            .WithMany(u => u.Capsules)
            .HasForeignKey(c => c.SenderId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Capsule>()
            .HasOne(c => c.UnlockedByUser)
            .WithMany()
            .HasForeignKey(c => c.UnlockedByUserId)
            .OnDelete(DeleteBehavior.SetNull);

        modelBuilder.Entity<Capsule>()
            .Property(c => c.Status)
            .HasDefaultValue("Locked");

        modelBuilder.Entity<Capsule>()
            .Property(c => c.ProximityTolerance)
            .HasDefaultValue(50);

        modelBuilder.Entity<User>()
            .HasMany(u => u.PasswordResetTokens)
            .WithOne(p => p.User)
            .HasForeignKey(p => p.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Friendship>()
            .HasOne(f => f.Requester)
            .WithMany(u => u.SentFriendRequests)
            .HasForeignKey(f => f.RequesterId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Friendship>()
            .HasOne(f => f.Addressee)
            .WithMany(u => u.ReceivedFriendRequests)
            .HasForeignKey(f => f.AddresseeId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Friendship>()
            .HasIndex(f => new { f.RequesterId, f.AddresseeId })
            .IsUnique();

        modelBuilder.Entity<PostLike>()
            .HasIndex(pl => new { pl.PostId, pl.UserId })
            .IsUnique();

        modelBuilder.Entity<PostLike>()
            .HasOne(pl => pl.Post).WithMany(p => p.Likes).HasForeignKey(pl => pl.PostId).OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<PostLike>()
            .HasOne(pl => pl.User).WithMany().HasForeignKey(pl => pl.UserId).OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<PostComment>()
            .HasOne(pc => pc.Post).WithMany(p => p.Comments).HasForeignKey(pc => pc.PostId).OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<PostComment>()
            .HasOne(pc => pc.User).WithMany().HasForeignKey(pc => pc.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
