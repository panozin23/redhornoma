#!/usr/bin/env python3
# Intermediario TDS v3: modifica el pre-login del CLIENTE (no del servidor).
# El cliente le dice al motor "no soporto cifrado" → ambos acuerdan sin
# cifrado desde el principio → el login va en claro (local) y Wine no usa
# su schannel roto.
import socket, threading, time

ESCUCHA = ("127.0.0.1", 1435)
MOTOR   = ("127.0.0.1", 1433)
def log(m): print("%.2f %s" % (time.time()%1000, m), flush=True)

def poner_notsup(datos, quien):
    # pre-login: cabecera 8 bytes + opciones. token 0x01=ENCRYPTION (1 byte).
    if len(datos) < 8: return datos, "corto"
    tipo = datos[0]
    # Cliente manda pre-login con tipo 0x12; servidor responde con 0x04.
    b = bytearray(datos); payload = b[8:]; i = 0; res = "sin-enc"
    while i + 5 <= len(payload):
        t = payload[i]
        if t == 0xFF: break
        off = (payload[i+1]<<8)|payload[i+2]; ln = (payload[i+3]<<8)|payload[i+4]
        if t == 0x01 and ln >= 1:
            pos = 8+off
            if pos < len(b):
                res = "%s ENC %d→2" % (quien, b[pos]); b[pos] = 0x02
        i += 5
    return bytes(b), res

def puente(origen, destino, lado, st):
    try:
        while True:
            d = origen.recv(16384)
            if not d: break
            # El PRIMER paquete de cada lado es el pre-login: lo tocamos en AMBOS.
            if lado == "cliente" and not st["c"]:
                d, r = poner_notsup(d, "cliente"); st["c"]=True; log("  "+r)
            if lado == "servidor" and not st["s"]:
                d, r = poner_notsup(d, "servidor"); st["s"]=True; log("  "+r)
            destino.sendall(d)
    except Exception as e:
        log("  %s err: %s" % (lado, e))
    finally:
        try: destino.shutdown(socket.SHUT_WR)
        except Exception: pass

def atiende(cli):
    log("cliente conectó")
    m = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try: m.connect(MOTOR)
    except Exception as e: log("no motor: %s"%e); cli.close(); return
    st = {"c":False,"s":False}
    t1=threading.Thread(target=puente,args=(cli,m,"cliente",st),daemon=True)
    t2=threading.Thread(target=puente,args=(m,cli,"servidor",st),daemon=True)
    t1.start();t2.start();t1.join();t2.join()
    cli.close();m.close();log("sesión cerrada")

def main():
    s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    s.bind(ESCUCHA);s.listen(20)
    log("intermediario %s:%d → %s:%d"%(ESCUCHA+MOTOR))
    while True:
        c,_=s.accept();threading.Thread(target=atiende,args=(c,),daemon=True).start()
main()
