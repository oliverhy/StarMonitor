#ifndef HTTPSERVER_H
#define HTTPSERVER_H

#include <system.h>

class CHttpServer
{
	static const int MAX_WEB_USERS = 64;
	static const int MAX_SESSIONS = 256;
	static const int MAX_CONNS = 64;
	static const int TOKEN_EXPIRE = 3600;

	struct CWebUser
	{
		bool m_Active;
		char m_aUsername[64];
		char m_aPassword[64];
	};

	struct CSession
	{
		bool m_Active;
		char m_aToken[128];
		char m_aUsername[64];
		int64 m_ExpireTime;
	};

	struct CConn
	{
		bool m_Active;
		NETSOCKET m_Socket;
		char m_aBuf[16384];
		int m_BufLen;
		char m_aResp[16384];
		int m_RespLen;
		int m_RespSent;
	};

	NETSOCKET m_ListenSocket;
	bool m_Ready;
	int m_Port;
	char m_aWebDir[1024];

	CWebUser m_aWebUsers[MAX_WEB_USERS];
	int m_NumWebUsers;
	CSession m_aSessions[MAX_SESSIONS];
	CConn m_aConns[MAX_CONNS];

	void GenToken(char *pBuf, int Size);
	CSession *FindSession(const char *pToken);
	CSession *AddSession(const char *pUsername);
	void DelSession(const char *pToken);
	void CleanSessions();
	void URLDecode(char *pDst, const char *pSrc, int DstSize);

	void Handle(CConn *pConn);
	void Resp(CConn *pConn, int Code, const char *pStatus, const char *pCT, const char *pBody, int BodyLen, const char *pExtraHdr);
	void RespFile(CConn *pConn, const char *pPath);
	void RespLoginPage(CConn *pConn);
	void RespStats(CConn *pConn);
	void CloseConn(CConn *pConn);
	const char *MimeType(const char *pPath);

public:
	CHttpServer();
	bool Init(const char *pWebDir, int Port);
	void Update();
	void AddUser(const char *pUsername, const char *pPassword);
	void ClearUsers();
	int NumUsers() const { return m_NumWebUsers; }
};

#endif
