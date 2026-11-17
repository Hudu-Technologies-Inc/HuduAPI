// Local HTTP fixture for exercising the real PowerShell client without credentials or Hudu.
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

namespace HuduAPI.Tests
{
    public sealed class Reply
    {
        public int Status;
        public string Body, Cookie, Location;
        public bool Close;
    }

    public sealed class Request
    {
        public string Method, Path, Query, Body;
        public int ClientPort;
        public Dictionary<string, string> Headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        private static string Quote(string value)
        {
            var result = new StringBuilder("\"");
            foreach (char ch in value ?? "")
            {
                if (ch == '\\' || ch == '"') result.Append('\\').Append(ch);
                else if (ch < 32) result.Append("\\u").Append(((int)ch).ToString("x4"));
                else result.Append(ch);
            }
            return result.Append('"').ToString();
        }
        public string ToJson()
        {
            var headers = new List<string>();
            foreach (var pair in Headers) headers.Add(Quote(pair.Key) + ":" + Quote(pair.Value));
            return "{\"method\":" + Quote(Method) + ",\"path\":" + Quote(Path) +
                ",\"query\":" + Quote(Query) + ",\"body\":" + Quote(Body) +
                ",\"clientPort\":" + ClientPort + ",\"headers\":{" + string.Join(",", headers) + "}}";
        }
    }

    public sealed class LoopbackServer : IDisposable
    {
        private readonly HttpListener listener = new HttpListener();
        private readonly Thread worker;
        private readonly ConcurrentQueue<Reply> replies = new ConcurrentQueue<Reply>();
        private readonly ConcurrentQueue<Request> requests = new ConcurrentQueue<Request>();
        private volatile bool stopping;
        public string BaseUrl { get; private set; }
        public Request[] Requests { get { return requests.ToArray(); } }
        public LoopbackServer()
        {
            var probe = new TcpListener(IPAddress.Loopback, 0);
            probe.Start();
            int port = ((IPEndPoint)probe.LocalEndpoint).Port;
            probe.Stop();
            BaseUrl = "http://127.0.0.1:" + port;
            listener.Prefixes.Add(BaseUrl + "/");
            listener.Start();
            worker = new Thread(Run) { IsBackground = true };
            worker.Start();
        }
        public void Enqueue(int status, string body = null, string cookie = null, bool close = false, string location = null)
        {
            replies.Enqueue(new Reply { Status = status, Body = string.IsNullOrEmpty(body) ? null : body, Cookie = cookie, Close = close, Location = location });
        }
        private void Run()
        {
            while (listener.IsListening)
            {
                HttpListenerContext context;
                try { context = listener.GetContext(); }
                catch (HttpListenerException) { break; }
                catch (ObjectDisposedException) { break; }
                try
                {
                    if (stopping) { context.Response.StatusCode = 204; context.Response.Close(); break; }
                    var incoming = context.Request;
                    var request = new Request { Method = incoming.HttpMethod, Path = incoming.Url.AbsolutePath,
                        Query = incoming.Url.Query, ClientPort = incoming.RemoteEndPoint.Port };
                    foreach (string key in incoming.Headers.AllKeys) request.Headers[key] = incoming.Headers[key];
                    using (var reader = new StreamReader(incoming.InputStream, Encoding.UTF8)) request.Body = reader.ReadToEnd();
                    requests.Enqueue(request);
                    Reply reply;
                    if (!replies.TryDequeue(out reply)) reply = new Reply { Status = 200 };
                    var response = context.Response;
                    response.StatusCode = reply.Status;
                    response.KeepAlive = !reply.Close;
                    response.ContentType = "application/json; charset=utf-8";
                    if (!string.IsNullOrEmpty(reply.Cookie)) response.Headers.Add("Set-Cookie", reply.Cookie);
                    if (!string.IsNullOrEmpty(reply.Location)) response.RedirectLocation = reply.Location;
                    byte[] bytes = Encoding.UTF8.GetBytes(reply.Body ?? request.ToJson());
                    response.ContentLength64 = bytes.Length;
                    response.OutputStream.Write(bytes, 0, bytes.Length);
                    response.Close();
                }
                catch (HttpListenerException) { }
                catch (IOException) { }
            }
        }
        public void Dispose()
        {
            // Wake GetContext explicitly, including on older .NET runtimes.
            stopping = true;
            try
            {
                using (var client = new TcpClient())
                {
                    var uri = new Uri(BaseUrl);
                    client.Connect(IPAddress.Loopback, uri.Port);
                    byte[] wakeup = Encoding.ASCII.GetBytes("GET /__stop__ HTTP/1.1\r\nHost: " + uri.Authority + "\r\nConnection: close\r\n\r\n");
                    client.GetStream().Write(wakeup, 0, wakeup.Length);
                }
            }
            catch (SocketException) { }
            catch (IOException) { }
            worker.Join(1000);
            listener.Close();
            worker.Join(1000);
        }
    }
}
