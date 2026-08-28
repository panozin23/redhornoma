#!/usr/bin/env python3
# Intermediario TDS para SOAPS: quita el cifrado que Wine (schannel) no completa.
# El cliente Wine se conecta a 127.0.0.1:1435; reenviamos a 127.0.0.1:1433.
# CLAVE: modificamos el saludo (PRE-LOGIN) DEL CLIENTE poniendo su opcion
# ENCRYPTION en NOT_SUP (0x02). Asi el MOTOR acepta no cifrar desde el inicio
# y ambos quedan de acuerdo (modificar solo la respuesta del motor desincroniza
# y cierra la conexion). El login viaja sin cifrar por el loopback local.
import socket, threading, time

ESCUCHA = ("127.0.0.1", 1435)
MOTOR   = ("127.0.0.1", 1433)

def log(m): print("%.2f %s" % (time.time() % 1000, m), flush=True)

def arregla_prelogin(datos):
    # PRE-LOGIN: cabecera TDS de 8 bytes + payload. Tipo 0x12 = request (cliente),
    # 0x04 = response (motor). Ambos llevan la opcion ENCRYPTION (token 0x01).
    if len(datos) < 8 or datos[0] not in (0x12, 0x04):
        return datos, "no-prelogin"
    b = bytearray(datos)
    payload = b[8:]
    i = 0; cambio = "sin-encryption"
    # Opciones: token(1) + offset(2) + length(2) ... hasta token 0xFF.
    while i + 5 <= len(payload):
        token = payload[i]
        if token == 0xFF:
            break
        off = (payload[i+1] << 8) | payload[i+2]
        ln  = (payload[i+3] << 8) | payload[i+4]
        if token == 0x01 and ln >= 1:          # ENCRYPTION
            pos = 8 + off
            if pos < len(b) and b[pos] in (0x00, 0x01):
                orig = b[pos]
                b[pos] = 0x02                   # -> NOT_SUP
                cambio = "ENCRYPTION %d->2" % orig
        i += 5
    return bytes(b), cambio

def puente(origen, destino, es_cliente, estado, nombre):
    try:
        while True:
            datos = origen.recv(16384)
            if not datos:
                break
            # Solo el PRIMER paquete del cliente (su PRE-LOGIN) se retoca.
            if es_cliente and not estado["pl"]:
                datos, c = arregla_prelogin(datos)
                estado["pl"] = True
                log("  pre-login del cliente (%d bytes): %s" % (len(datos), c))
            destino.sendall(datos)
    except Exception as e:
        log("  %s: error %s" % (nombre, e))
    finally:
        try: destino.shutdown(socket.SHUT_WR)
        except Exception: pass

def atiende(cliente):
    motor = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        motor.connect(MOTOR)
    except Exception as e:
        log("no conecto al motor: %s" % e); cliente.close(); return
    st = {"pl": False}
    t1 = threading.Thread(target=puente, args=(cliente, motor, True,  st, "cliente->motor"), daemon=True)
    t2 = threading.Thread(target=puente, args=(motor, cliente, False, st, "motor->cliente"), daemon=True)
    t1.start(); t2.start(); t1.join(); t2.join()
    cliente.close(); motor.close()

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(ESCUCHA); s.listen(20)
    log("intermediario en %s:%d -> %s:%d" % (ESCUCHA + MOTOR))
    while True:
        c, _ = s.accept()
        threading.Thread(target=atiende, args=(c,), daemon=True).start()

main()
