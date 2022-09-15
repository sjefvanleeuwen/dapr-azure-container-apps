using System.Text;
using Dapr.Client;
using Lucene.Net.Analysis.Standard;
using Lucene.Net.Index;
using Lucene.Net.Store;
using Lucene.Net.Util;

const LuceneVersion AppLuceneVersion = LuceneVersion.LUCENE_48;

// Construct a machine-independent path for the index
var basePath = Environment.GetFolderPath(
    Environment.SpecialFolder.CommonApplicationData);
var indexPath = Path.Combine(basePath, "index");

using var dir = FSDirectory.Open(indexPath);

// Create an analyzer to process the text
var analyzer = new StandardAnalyzer(AppLuceneVersion);

// Create an index writer
var indexConfig = new IndexWriterConfig(AppLuceneVersion, analyzer);
using var writer = new IndexWriter(dir, indexConfig);


var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDaprClient();
//builder.Services.AddControllers().AddDapr();
var app = builder.Build();
// Dapr will send serialized event object vs. being raw CloudEvent
app.UseCloudEvents();
var client = app.Services.GetRequiredService<DaprClient>();

// needed for Dapr pub/sub routing
app.MapSubscribeHandler();

if (app.Environment.IsDevelopment()) { app.UseDeveloperExceptionPage(); }
app.MapGet("/search", async () =>
{
    return Results.NoContent();
});
app.MapGet("/", () =>
{
    return Results.Content("lucene search services", "text/html", Encoding.UTF8);
});
await app.RunAsync();
