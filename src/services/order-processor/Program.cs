using System.Text;
using System.Text.Json.Serialization;
using Dapr;
using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDaprClient();
//builder.Services.AddControllers().AddDapr();
var app = builder.Build();
// Dapr will send serialized event object vs. being raw CloudEvent
app.UseCloudEvents();
var client = app.Services.GetRequiredService<DaprClient>();

// needed for Dapr pub/sub routing
app.MapSubscribeHandler();

SemaphoreSlim semaphoreSlim = new SemaphoreSlim(1, 1);


if (app.Environment.IsDevelopment()) { app.UseDeveloperExceptionPage(); }
app.MapGet("/orders", async () => {
    var total = await client.GetStateAsync<int>("statestore", "order-total", ConsistencyMode.Eventual);
    return Results.Ok(total);
});
app.MapGet("/", () => {
    return Results.Content("order service <a href='./orders'>orders</a>", "text/html", Encoding.UTF8);
});

// Dapr subscription in [Topic] routes orders topic to this route
app.MapPost("/orders", [Topic("pubsub", "newOrder")] async (Order order) =>
{
    await semaphoreSlim.WaitAsync();
    var total = await client.GetStateAsync<int>("statestore", "order-total", ConsistencyMode.Eventual);
    total++;
    await client.SaveStateAsync<int>("statestore", "order-total", total);
    total = await client.GetStateAsync<int>("statestore", "order-total", ConsistencyMode.Eventual);
    Console.WriteLine($"Total Orders {total} New Order Subscriber received : " + order);
    semaphoreSlim.Release();
    return Results.Ok(order);

});
//[FromState("statestore", "total-orders")] StateEntry<int> total,
await app.RunAsync();

public record Order([property: JsonPropertyName("orderId")] int OrderId);