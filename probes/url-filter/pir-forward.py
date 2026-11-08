import asyncio, sys
# Forwards the LAN port to the reverse-tunnelled PIR server on loopback, so the
# iPad can reach a server running on the Windows PC (#83). Stops with its ssh.
LISTEN, TARGET = int(sys.argv[1]), int(sys.argv[2])
async def pipe(r, w):
    try:
        while data := await r.read(65536):
            w.write(data); await w.drain()
    finally:
        w.close()
async def handle(cr, cw):
    try:
        tr, tw = await asyncio.open_connection("127.0.0.1", TARGET)
    except OSError as e:
        print("upstream refused:", e, flush=True); cw.close(); return
    await asyncio.gather(pipe(cr, tw), pipe(tr, cw), return_exceptions=True)
async def main():
    s = await asyncio.start_server(handle, "0.0.0.0", LISTEN)
    print(f"forwarding 0.0.0.0:{LISTEN} -> 127.0.0.1:{TARGET}", flush=True)
    async with s: await s.serve_forever()
asyncio.run(main())
