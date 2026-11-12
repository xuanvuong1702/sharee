using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Hubs;

[Authorize]
public sealed class ChatHub(ChatService chat) : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId = Context.User!.GetUserId();
        await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
        await base.OnConnectedAsync();
    }

    public async Task JoinConversation(Guid conversationId)
    {
        var userId = Context.User!.GetUserId();
        if (await chat.IsParticipantAsync(conversationId, userId))
            await Groups.AddToGroupAsync(Context.ConnectionId, $"conv:{conversationId}");
    }

    public async Task SendMessage(Guid conversationId, string body)
    {
        if (string.IsNullOrWhiteSpace(body) || body.Length > 2000) return;
        var userId = Context.User!.GetUserId();
        if (!await chat.IsParticipantAsync(conversationId, userId)) return;

        var message = await chat.SendAsync(conversationId, userId, body.Trim());
        var otherId = await chat.GetOtherUserIdAsync(conversationId, userId);

        await Clients.Group($"conv:{conversationId}").SendAsync("message", message);
        await Clients.Group($"user:{otherId}").SendAsync("thread", message);
    }
}
