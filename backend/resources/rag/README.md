# PDF RAG Resources

- Put source PDFs in `backend/resources/rag/pdfs/`.
- The backend builds a lazy in-memory index on the first chat request.
- A JSON cache is written to `backend/resources/rag/rag_index_cache.json` after the first successful parse.
- If you replace or add PDFs, the cache is rebuilt automatically on the next request.

## Local verification

1. Install backend dependencies with Python 3.11 or newer.

```bash
C:\Users\SSAFY\AppData\Local\Programs\Python\Python311\python.exe -m pip install -r backend/requirements.txt
```

2. Start the backend. On startup, the server logs `RAG startup status: ...` and prebuilds the cache.

For quick local RAG checks without local login state, you can enable anonymous chat mode:

```powershell
$env:CHAT_ALLOW_ANONYMOUS="true"
C:\Users\SSAFY\AppData\Local\Programs\Python\Python311\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000
```

3. Run the Flutter app against the local backend only when you want to test local RAG:

```bash
flutter run --dart-define=BACKEND_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For a physical Android device, replace `10.0.2.2` with your PC's local IP.

4. Ask a document-heavy question and check:

- backend log: `chat rag sources user=... sources=[...]`
- cache file exists: `backend/resources/rag/rag_index_cache.json`
- app debug log: `[ChatRepository] model=... sources=...`

Current bundled PDFs:

- `fundamental-concepts-in-emg-signal-acquisition.pdf`
- `seniam_commentary.en.pdf`
- `seniam_recommendations.en.pdf`
- `Your-Home-Exercise-Plan-ML3403.pdf`
