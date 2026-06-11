#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <system.h>
#include <json.h>
#include "httpserver.h"

static const char *LOGIN_PAGE =
"<html><head><meta charset='utf-8'><title>StarMonitor 登录</title>"
"<meta name='viewport' content='width=device-width,initial-scale=1'>"
"<style>"
"*{margin:0;padding:0;box-sizing:border-box}"
"body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0f1923;display:flex;align-items:center;justify-content:center;min-height:100vh}"
".box{background:#1a2a3a;padding:40px;border-radius:12px;box-shadow:0 8px 32px rgba(0,0,0,.4);width:360px}"
"h1{color:#e0e8f0;text-align:center;margin-bottom:30px;font-size:24px}"
"input{width:100%;padding:12px 16px;margin-bottom:16px;border:1px solid #2a3a4a;border-radius:8px;background:#0f1923;color:#e0e8f0;font-size:14px;outline:0}"
"input:focus{border-color:#4a9eff}"
"button{width:100%;padding:12px;background:#4a9eff;color:#fff;border:0;border-radius:8px;font-size:16px;cursor:pointer}"
"button:hover{background:#3a8eef}"
".err{color:#ff6b6b;text-align:center;margin-bottom:16px;display:none}"
"</style></head><body>"
"<div class='box'><h1>StarMonitor</h1>"
"<div class='err' id='err'></div>"
"<input type='text' id='user' placeholder='用户名' autocomplete='username'>"
"<input type='password' id='pass' placeholder='密码' autocomplete='current-password'>"
"<button onclick='login()'>登录</button></div>"
"<script>"
"function login(){var u=document.getElementById('user').value,p=document.getElementById('pass').value;"
"if(!u||!p){show('请输入用户名和密码');return}"
"var x=new XMLHttpRequest();x.open('POST','/login',true);"
"x.setRequestHeader('Content-Type','application/x-www-form-urlencoded');"
"x.onload=function(){if(x.status==200){var t=JSON.parse(x.responseText).token;"
"document.cookie='token='+t+';path=/;max-age=3600';location.href='/dashboard'}else show('用户名或密码错误')};"
"x.onerror=function(){show('请求失败')};x.send('username='+encodeURIComponent(u)+'&password='+encodeURIComponent(p))}"
"function show(m){var e=document.getElementById('err');e.textContent=m;e.style.display='block'}"
"</script></body></html>";

static const char *DASHBOARD_PAGE =
"<html><head><meta charset='utf-8'><title>StarMonitor</title>"
"<meta name='viewport' content='width=device-width,initial-scale=1'>"
"<style>"
"*{margin:0;padding:0;box-sizing:border-box}"
"body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0f1923;color:#e0e8f0;padding:20px}"
".hd{display:flex;justify-content:space-between;align-items:center;margin-bottom:24px}"
"h1{font-size:22px}"
".logout{color:#ff6b6b;cursor:pointer;text-decoration:none;font-size:14px}"
".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:16px}"
".card{background:#1a2a3a;border-radius:10px;padding:20px;position:relative}"
".card.offline{opacity:.5}"
".card h2{font-size:16px;margin-bottom:12px}"
".card .loc{font-size:12px;color:#8899aa;margin-bottom:12px}"
".row{display:flex;justify-content:space-between;padding:4px 0;font-size:13px}"
".row .l{color:#8899aa}.row .r{color:#e0e8f0}"
".tag{display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;margin-left:8px}"
".tag.on{background:#2ecc71;color:#fff}"
".tag.off{background:#e74c3c;color:#fff}"
".bar{margin:8px 0;height:6px;background:#0f1923;border-radius:3px;overflow:hidden}"
".bar>div{height:100%;border-radius:3px;transition:width .5s}"
".bar.cpu>div{background:#4a9eff}"
".bar.mem>div{background:#2ecc71}"
".bar.hdd>div{background:#f39c12}"
".updated{text-align:center;color:#556677;font-size:12px;margin-top:24px}"
"</style></head><body>"
"<div class='hd'><h1>StarMonitor</h1><a class='logout' href='/logout'>退出登录</a></div>"
"<div class='grid' id='grid'></div>"
"<div class='updated' id='updated'></div>"
"<script>"
"function fmt(b){if(!b)return'0 B';var u=['B','KB','MB','GB','TB'];var i=0;var s=Number(b);while(s>=1024&&i<4){s/=1024;i++}return s.toFixed(1)+' '+u[i]}"
"function load(){var t='';var c=document.cookie.split('; ');for(var i=0;i<c.length;i++){if(c[i].startsWith('token=')){t=c[i].substr(6);break}}"
"if(!t){location.href='/';return}"
"var x=new XMLHttpRequest();x.open('GET','/stats?token='+encodeURIComponent(t),true);"
"x.onload=function(){if(x.status==200){render(JSON.parse(x.responseText))}else if(x.status==401){location.href='/'}};x.send()}"
"function render(d){var g=document.getElementById('grid');g.innerHTML='';"
"for(var i=0;i<d.servers.length;i++){var s=d.servers[i];var on=s.online4||s.online6;"
"var c=document.createElement('div');c.className='card'+(on?'':' offline');"
"var h='<h2>'+s.name+'<span class=\"tag '+(on?'on':'off')+'\">'+(on?'在线':'离线')+'</span></h2>';"
"h+='<div class=\"loc\">'+s.location+' · '+s.type+'</div>';"
"if(on){h+='<div class=\"row\"><span class=\"l\">运行时间</span><span class=\"r\">'+s.uptime+'</span></div>';"
"h+='<div class=\"row\"><span class=\"l\">负载</span><span class=\"r\">'+s.load.toFixed(2)+'</span></div>';"
"h+='<div class=\"row\"><span class=\"l\">CPU</span><span class=\"r\">'+s.cpu+'%</span></div>';"
"h+='<div class=\"bar cpu\"><div style=\"width:'+Math.min(s.cpu,100)+'%\"></div></div>';"
"h+='<div class=\"row\"><span class=\"l\">内存</span><span class=\"r\">'+fmt(s.memory_used)+' / '+fmt(s.memory_total)+'</span></div>';"
"h+='<div class=\"bar mem\"><div style=\"width:'+(s.memory_total?((s.memory_used/s.memory_total)*100).toFixed(0):0)+'%\"></div></div>';"
"h+='<div class=\"row\"><span class=\"l\">硬盘</span><span class=\"r\">'+fmt(s.hdd_used)+' / '+fmt(s.hdd_total)+'</span></div>';"
"h+='<div class=\"bar hdd\"><div style=\"width:'+(s.hdd_total?((s.hdd_used/s.hdd_total)*100).toFixed(0):0)+'%\"></div></div>';"
"h+='<div class=\"row\"><span class=\"l\">流量 ↓</span><span class=\"r\">'+fmt(s.network_in)+'</span></div>';"
"h+='<div class=\"row\"><span class=\"l\">流量 ↑</span><span class=\"r\">'+fmt(s.network_out)+'</span></div>'}else{h+='<div style=\"color:#556677\">等待连接...</div>'}"
"c.innerHTML=h;g.appendChild(c)}"
"document.getElementById('updated').textContent='更新于 '+d.updated}"
"load();setInterval(load,5000)"
"</script></body></html>";

CHttpServer::CHttpServer()
{
	m_ListenSocket.type = NETTYPE_INVALID;
	m_ListenSocket.ipv4sock = -1;
	m_ListenSocket.ipv6sock = -1;
	m_Ready = false;
	m_Port = 0;
	m_aWebDir[0] = 0;
	m_NumWebUsers = 0;
	for(int i = 0; i < MAX_SESSIONS; i++)
		m_aSessions[i].m_Active = false;
	for(int i = 0; i < MAX_CONNS; i++)
		m_aConns[i].m_Active = false;
}

bool CHttpServer::Init(const char *pWebDir, int Port)
{
	m_aWebDir[0] = 0;
	if(pWebDir)
		str_copy(m_aWebDir, pWebDir, sizeof(m_aWebDir));
	m_Port = Port;

	NETADDR BindAddr;
	mem_zero(&BindAddr, sizeof(BindAddr));
	BindAddr.type = NETTYPE_ALL;
	BindAddr.port = Port;

	m_ListenSocket = net_tcp_create(BindAddr);
	if(!m_ListenSocket.type)
	{
		dbg_msg("httpserver", "Failed to create socket on port %d", Port);
		return false;
	}
	if(net_tcp_listen(m_ListenSocket, 64))
	{
		dbg_msg("httpserver", "Failed to listen on port %d", Port);
		net_tcp_close(m_ListenSocket);
		return false;
	}
	net_set_non_blocking(m_ListenSocket);
	for(int i = 0; i < MAX_CONNS; i++)
		m_aConns[i].m_Active = false;
	m_Ready = true;
	dbg_msg("httpserver", "HTTP server listening on port %d", Port);
	return true;
}

void CHttpServer::AddUser(const char *pUsername, const char *pPassword)
{
	if(m_NumWebUsers >= MAX_WEB_USERS)
	{
		dbg_msg("httpserver", "Max web users reached");
		return;
	}
	str_copy(m_aWebUsers[m_NumWebUsers].m_aUsername, pUsername, sizeof(m_aWebUsers[0].m_aUsername));
	str_copy(m_aWebUsers[m_NumWebUsers].m_aPassword, pPassword, sizeof(m_aWebUsers[0].m_aPassword));
	m_aWebUsers[m_NumWebUsers].m_Active = true;
	m_NumWebUsers++;
}

void CHttpServer::ClearUsers()
{
	m_NumWebUsers = 0;
}

void CHttpServer::GenToken(char *pBuf, int Size)
{
	static const char *hex = "0123456789abcdef";
	for(int i = 0; i < Size - 1; i++)
		pBuf[i] = hex[(int)((double)rand() / (RAND_MAX + 1.0) * 16)];
	pBuf[Size - 1] = 0;
}

CHttpServer::CSession *CHttpServer::FindSession(const char *pToken)
{
	for(int i = 0; i < MAX_SESSIONS; i++)
	{
		if(m_aSessions[i].m_Active && str_comp(m_aSessions[i].m_aToken, pToken) == 0)
		{
			if(time_get() < m_aSessions[i].m_ExpireTime)
				return &m_aSessions[i];
			m_aSessions[i].m_Active = false;
			return 0;
		}
	}
	return 0;
}

CHttpServer::CSession *CHttpServer::AddSession(const char *pUsername)
{
	for(int i = 0; i < MAX_SESSIONS; i++)
	{
		if(!m_aSessions[i].m_Active)
		{
			GenToken(m_aSessions[i].m_aToken, sizeof(m_aSessions[i].m_aToken));
			str_copy(m_aSessions[i].m_aUsername, pUsername, sizeof(m_aSessions[i].m_aUsername));
			m_aSessions[i].m_ExpireTime = time_get() + TOKEN_EXPIRE * time_freq();
			m_aSessions[i].m_Active = true;
			return &m_aSessions[i];
		}
	}
	return 0;
}

void CHttpServer::DelSession(const char *pToken)
{
	for(int i = 0; i < MAX_SESSIONS; i++)
	{
		if(m_aSessions[i].m_Active && str_comp(m_aSessions[i].m_aToken, pToken) == 0)
		{
			m_aSessions[i].m_Active = false;
			return;
		}
	}
}

void CHttpServer::CleanSessions()
{
	int64 now = time_get();
	for(int i = 0; i < MAX_SESSIONS; i++)
	{
		if(m_aSessions[i].m_Active && now >= m_aSessions[i].m_ExpireTime)
			m_aSessions[i].m_Active = false;
	}
}

void CHttpServer::URLDecode(char *pDst, const char *pSrc, int DstSize)
{
	int pos = 0;
	while(*pSrc && pos < DstSize - 1)
	{
		if(*pSrc == '%' && *(pSrc+1) && *(pSrc+2))
		{
			char h[3] = {pSrc[1], pSrc[2], 0};
			pDst[pos++] = (char)strtol(h, 0, 16);
			pSrc += 3;
		}
		else if(*pSrc == '+')
		{
			pDst[pos++] = ' ';
			pSrc++;
		}
		else
			pDst[pos++] = *pSrc++;
	}
	pDst[pos] = 0;
}

void CHttpServer::Resp(CConn *pConn, int Code, const char *pStatus, const char *pCT, const char *pBody, int BodyLen, const char *pExtraHdr)
{
	char aHdr[2048];
	str_format(aHdr, sizeof(aHdr),
		"HTTP/1.1 %d %s\r\n"
		"Content-Length: %d\r\n"
		"Content-Type: %s\r\n"
		"Connection: close\r\n"
		"%s"
		"\r\n",
		Code, pStatus, BodyLen, pCT, pExtraHdr ? pExtraHdr : "");
	int HdrLen = str_length(aHdr);

	// Send headers
	int sent = 0;
	int attempts = 0;
	while(sent < HdrLen && attempts < 100)
	{
		int ret = net_tcp_send(pConn->m_Socket, aHdr + sent, HdrLen - sent);
		if(ret > 0)
		{
			sent += ret;
			attempts = 0;
		}
		else
		{
			attempts++;
			thread_sleep(1);
		}
	}

	// Send body (can be large, send directly from source buffer)
	sent = 0;
	attempts = 0;
	while(sent < BodyLen && attempts < 100)
	{
		int ret = net_tcp_send(pConn->m_Socket, pBody + sent, BodyLen - sent);
		if(ret > 0)
		{
			sent += ret;
			attempts = 0;
		}
		else
		{
			attempts++;
			thread_sleep(1);
		}
	}
}

void CHttpServer::RespFile(CConn *pConn, const char *pPath)
{
	char aFull[1024];
	str_format(aFull, sizeof(aFull), "%s%s", m_aWebDir, pPath);
	IOHANDLE f = io_open(aFull, IOFLAG_READ);
	if(!f)
	{
		const char *msg = "404 Not Found";
		Resp(pConn, 404, "Not Found", "text/plain", msg, str_length(msg), 0);
		return;
	}
	int size = (int)io_length(f);
	char *buf = (char *)mem_alloc(size + 1, 1);
	io_read(f, buf, size);
	buf[size] = 0;
	io_close(f);
	Resp(pConn, 200, "OK", MimeType(pPath), buf, size, 0);
	mem_free(buf);
}

const char *CHttpServer::MimeType(const char *pPath)
{
	const char *ext = strrchr(pPath, '.');
	if(!ext) return "application/octet-stream";
	if(str_comp(ext, ".html") == 0) return "text/html; charset=utf-8";
	if(str_comp(ext, ".css") == 0) return "text/css; charset=utf-8";
	if(str_comp(ext, ".js") == 0) return "application/javascript";
	if(str_comp(ext, ".png") == 0) return "image/png";
	if(str_comp(ext, ".jpg") == 0 || str_comp(ext, ".jpeg") == 0) return "image/jpeg";
	if(str_comp(ext, ".gif") == 0) return "image/gif";
	if(str_comp(ext, ".svg") == 0) return "image/svg+xml";
	if(str_comp(ext, ".ico") == 0) return "image/x-icon";
	if(str_comp(ext, ".json") == 0) return "application/json";
	return "application/octet-stream";
}

void CHttpServer::RespLoginPage(CConn *pConn)
{
	Resp(pConn, 200, "OK", "text/html; charset=utf-8", LOGIN_PAGE, str_length(LOGIN_PAGE), 0);
}

void CHttpServer::RespStats(CConn *pConn)
{
	// Read the stats.json file written by the main thread
	char aPath[1024];
	str_format(aPath, sizeof(aPath), "%sjson/stats.json", m_aWebDir);
	IOHANDLE f = io_open(aPath, IOFLAG_READ);
	if(!f)
	{
		const char *msg = "{\"error\":\"no data\"}";
		Resp(pConn, 200, "OK", "application/json", msg, str_length(msg), 0);
		return;
	}
	int size = (int)io_length(f);
	char *buf = (char *)mem_alloc(size + 1, 1);
	io_read(f, buf, size);
	buf[size] = 0;
	io_close(f);
	Resp(pConn, 200, "OK", "application/json", buf, size, 0);
	mem_free(buf);
}

void CHttpServer::CloseConn(CConn *pConn)
{
	if(pConn->m_Active)
	{
		net_tcp_close(pConn->m_Socket);
		pConn->m_Active = false;
	}
}

void CHttpServer::Handle(CConn *pConn)
{
	// Parse HTTP request
	char *pReq = pConn->m_aBuf;
	char aMethod[16] = {0};
	char aPath[1024] = {0};

	// Parse method
	int i = 0;
	while(pReq[i] && pReq[i] != ' ' && i < (int)sizeof(aMethod) - 1)
	{
		aMethod[i] = pReq[i];
		i++;
	}
	aMethod[i] = 0;
	if(!pReq[i]) { CloseConn(pConn); return; }
	i++; // skip space

	// Parse path
	int j = 0;
	while(pReq[i] && pReq[i] != ' ' && pReq[i] != '?' && j < (int)sizeof(aPath) - 1)
	{
		aPath[j] = pReq[i];
		i++;
		j++;
	}
	aPath[j] = 0;

	// Parse query string
	char aQuery[2048] = {0};
	if(pReq[i] == '?')
	{
		i++;
		j = 0;
		while(pReq[i] && pReq[i] != ' ' && j < (int)sizeof(aQuery) - 1)
		{
			aQuery[j] = pReq[i];
			i++;
			j++;
		}
		aQuery[j] = 0;
	}

	// Extract token from query string
	char aToken[256] = {0};
	{
		const char *q = aQuery;
		while(*q)
		{
			if(str_comp_num(q, "token=", 6) == 0)
			{
				const char *v = q + 6;
				int k = 0;
				while(*v && *v != '&' && k < (int)sizeof(aToken) - 1)
					aToken[k++] = *v++;
				aToken[k] = 0;
				break;
			}
			while(*q && *q != '&') q++;
			if(*q == '&') q++;
		}
	}

	// Extract token from Cookie header
	if(!aToken[0])
	{
		const char *pCookie = str_find(pReq, "Cookie: ");
		if(pCookie)
		{
			pCookie += 8;
			const char *pTok = str_find(pCookie, "token=");
			if(pTok)
			{
				pTok += 6;
				int k = 0;
				while(*pTok && *pTok != ';' && *pTok != '\r' && *pTok != '\n' && k < (int)sizeof(aToken) - 1)
					aToken[k++] = *pTok++;
				aToken[k] = 0;
			}
		}
	}

	// Route
	if(str_comp(aMethod, "GET") == 0)
	{
		if(str_comp(aPath, "/") == 0 || str_comp(aPath, "/login") == 0)
		{
			RespLoginPage(pConn);
		}
		else if(str_comp(aPath, "/dashboard") == 0)
		{
			if(!FindSession(aToken))
			{
				const char *body = "<html><body><script>location.href='/'</script></body></html>";
				Resp(pConn, 401, "Unauthorized", "text/html", body, str_length(body),
					"Set-Cookie: token=; path=/; max-age=0\r\n");
			}
			else
				Resp(pConn, 200, "OK", "text/html; charset=utf-8", DASHBOARD_PAGE, str_length(DASHBOARD_PAGE), 0);
		}
		else if(str_comp(aPath, "/stats") == 0)
		{
			if(!FindSession(aToken))
			{
				const char *msg = "{\"error\":\"unauthorized\"}";
				Resp(pConn, 401, "Unauthorized", "application/json", msg, str_length(msg), 0);
			}
			else
				RespStats(pConn);
		}
		else if(str_comp(aPath, "/logout") == 0)
		{
			if(aToken[0])
				DelSession(aToken);
			const char *body = "<html><body><script>location.href='/'</script></body></html>";
			Resp(pConn, 200, "OK", "text/html", body, str_length(body),
				"Set-Cookie: token=; path=/; max-age=0\r\n");
		}
		else
		{
			// Try to serve static file
			char aFilePath[1024];
			if(aPath[0] == '/')
				str_copy(aFilePath, aPath + 1, sizeof(aFilePath));
			else
				str_copy(aFilePath, aPath, sizeof(aFilePath));

			if(!aFilePath[0])
				str_copy(aFilePath, "index.html", sizeof(aFilePath));

			RespFile(pConn, aFilePath);
		}
	}
	else if(str_comp(aMethod, "POST") == 0)
	{
		if(str_comp(aPath, "/login") == 0)
		{
			// Parse POST body
			const char *pBody = str_find(pReq, "\r\n\r\n");
			if(!pBody) { CloseConn(pConn); return; }
			pBody += 4;

			char aUsername[64] = {0};
			char aPassword[64] = {0};

			// Parse form data
			const char *p = pBody;
			while(*p)
			{
				char aKey[64] = {0};
				char aVal[256] = {0};
				int k = 0;
				while(*p && *p != '=' && *p != '&' && k < (int)sizeof(aKey) - 1)
					aKey[k++] = *p++;
				aKey[k] = 0;
				if(*p == '=') p++;
				int v = 0;
				while(*p && *p != '&' && v < (int)sizeof(aVal) - 1)
					aVal[v++] = *p++;
				aVal[v] = 0;
				if(*p == '&') p++;

				if(str_comp(aKey, "username") == 0)
					URLDecode(aUsername, aVal, sizeof(aUsername));
				else if(str_comp(aKey, "password") == 0)
					URLDecode(aPassword, aVal, sizeof(aPassword));
			}

			// Verify credentials
			bool ok = false;
			for(int i = 0; i < m_NumWebUsers; i++)
			{
				if(m_aWebUsers[i].m_Active &&
					str_comp(m_aWebUsers[i].m_aUsername, aUsername) == 0 &&
					str_comp(m_aWebUsers[i].m_aPassword, aPassword) == 0)
				{
					ok = true;
					break;
				}
			}

			if(ok)
			{
				CSession *s = AddSession(aUsername);
				if(s)
				{
					char aResp[512];
					str_copy(aResp, "{\"token\":\"", sizeof(aResp));
					str_append(aResp, s->m_aToken, sizeof(aResp));
					str_append(aResp, "\",\"username\":\"", sizeof(aResp));
					str_append(aResp, s->m_aUsername, sizeof(aResp));
					str_append(aResp, "\"}", sizeof(aResp));
					int n = str_length(aResp);
					char aHdr[256];
					str_copy(aHdr, "Set-Cookie: token=", sizeof(aHdr));
					str_append(aHdr, s->m_aToken, sizeof(aHdr));
					str_append(aHdr, "; path=/; max-age=3600\r\n", sizeof(aHdr));
					fprintf(stderr, "[httpserver] login OK user=%s resp=%d hdr=%d\n", aUsername, n, str_length(aHdr));
					Resp(pConn, 200, "OK", "application/json", aResp, n, aHdr);
				}
				else
				{
					fprintf(stderr, "[httpserver] login OK but too many sessions\n");
					const char *msg = "{\"error\":\"too many sessions\"}";
					Resp(pConn, 503, "Service Unavailable", "application/json", msg, str_length(msg), 0);
				}
			}
			else
			{
				fprintf(stderr, "[httpserver] login FAILED user='%s' nusers=%d\n", aUsername, m_NumWebUsers);
				const char *msg = "{\"error\":\"invalid credentials\"}";
				Resp(pConn, 401, "Unauthorized", "application/json", msg, str_length(msg), 0);
			}
		}
		else
		{
			const char *msg = "404 Not Found";
			Resp(pConn, 404, "Not Found", "text/plain", msg, str_length(msg), 0);
		}
	}
	else
	{
		const char *msg = "405 Method Not Allowed";
		Resp(pConn, 405, "Method Not Allowed", "text/plain", msg, str_length(msg), 0);
	}

	CloseConn(pConn);
}

void CHttpServer::Update()
{
	if(!m_Ready)
		return;

	CleanSessions();

	// Accept new connections
	NETSOCKET NewSock;
	NETADDR Addr;
	while(net_tcp_accept(m_ListenSocket, &NewSock, &Addr) > 0)
	{
		int slot = -1;
		for(int i = 0; i < MAX_CONNS; i++)
		{
			if(!m_aConns[i].m_Active)
			{
				slot = i;
				break;
			}
		}
		if(slot == -1)
		{
			net_tcp_send(NewSock, "HTTP/1.1 503 Service Unavailable\r\n\r\n", 37);
			net_tcp_close(NewSock);
			continue;
		}
		net_set_non_blocking(NewSock);
		m_aConns[slot].m_Active = true;
		m_aConns[slot].m_Socket = NewSock;
		m_aConns[slot].m_BufLen = 0;
	}

	// Read from connections
	for(int i = 0; i < MAX_CONNS; i++)
	{
		if(!m_aConns[i].m_Active)
			continue;

		int bytes = net_tcp_recv(m_aConns[i].m_Socket,
			m_aConns[i].m_aBuf + m_aConns[i].m_BufLen,
			(int)sizeof(m_aConns[i].m_aBuf) - m_aConns[i].m_BufLen - 1);

		if(bytes > 0)
		{
			m_aConns[i].m_BufLen += bytes;
			m_aConns[i].m_aBuf[m_aConns[i].m_BufLen] = 0;

			// Check if we have complete headers
			if(str_find(m_aConns[i].m_aBuf, "\r\n\r\n"))
			{
				// For POST, wait for full body based on Content-Length
				const char *pCL = str_find_nocase(m_aConns[i].m_aBuf, "Content-Length: ");
				int bodyLen = 0;
				if(pCL)
				{
					pCL += 16;
					while(*pCL >= '0' && *pCL <= '9')
					{
						bodyLen = bodyLen * 10 + (*pCL - '0');
						pCL++;
					}
				}
				const char *pSep = str_find(m_aConns[i].m_aBuf, "\r\n\r\n");
				int headerEnd = (int)(pSep - m_aConns[i].m_aBuf) + 4;
				int totalNeeded = headerEnd + bodyLen;
				if(m_aConns[i].m_BufLen < totalNeeded)
				{
					// Body not fully received yet, wait for more data
					continue;
				}
				Handle(&m_aConns[i]);
			}
			else if(m_aConns[i].m_BufLen >= (int)sizeof(m_aConns[i].m_aBuf) - 1)
			{
				// Buffer full without complete headers
				const char *msg = "HTTP/1.1 413 Payload Too Large\r\n\r\n";
				net_tcp_send(m_aConns[i].m_Socket, msg, str_length(msg));
				CloseConn(&m_aConns[i]);
			}
		}
		else if(bytes == 0)
		{
			// Connection closed
			CloseConn(&m_aConns[i]);
		}
		else if(bytes < 0)
		{
			if(!net_would_block())
				CloseConn(&m_aConns[i]);
		}
	}
}
