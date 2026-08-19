/* El pase de diapositivas que se ve MIENTRAS se instala RedHornoma.
 *
 * EL PORQUÉ
 *
 * La instalación tarda unos diez minutos, y durante ese rato la persona
 * mira la pantalla sin nada que hacer. Es el único momento garantizado en
 * que alguien de un centro de salud va a leer algo de este sistema.
 *
 * El de Debian aprovechaba ese rato para hablar de software libre y de la
 * comunidad. Aquí se aprovecha para enseñar LO QUE VA A NECESITAR EN
 * CUANTO TERMINE, en el orden en que lo va a necesitar:
 *
 *   1 · qué es esto y qué protege
 *   2 · lo PRIMERO que hay que abrir al terminar
 *   3 · que la información se guarda sola, y a dónde
 *   4 · qué hacer cuando algo falle
 *   5 · dónde están los programas del Ministerio
 *
 * Sin palabras de informático, y sin dar por sabido nada. Si al terminar
 * la instalación la persona sabe abrir «Preparar el centro», este pase ha
 * hecho más que cualquier manual.
 */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    // 18 segundos por pantalla: lo que se tarda en leer un párrafo corto
    // sin prisa. Cinco pantallas dan la vuelta cada minuto y medio, y una
    // instalación dura lo bastante para verlas varias veces.
    Timer {
        interval: 18000
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    // Todas las pantallas se dibujan igual: un título grande y un texto
    // debajo. Sin imágenes que haya que mantener ni que puedan faltar.
    Slide {
        Column {
            anchors.centerIn: parent
            width: 640
            spacing: 24
            Text {
                width: parent.width
                horizontalAlignment: Text.Center
                font.pixelSize: 30
                color: "#1c4b5a"
                text: qsTr("Se está instalando RedHornoma")
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.Center
                font.pixelSize: 17
                lineHeight: 1.35
                text: qsTr("Es el sistema de los centros de salud: guarda la información " +
                           "de los pacientes, la copia sola todas las noches, y deja que " +
                           "varias computadoras trabajen sobre los mismos datos.<br/><br/>" +
                           "Esto tarda unos minutos. No hay que hacer nada.")
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            width: 640
            spacing: 24
            Text {
                width: parent.width
                horizontalAlignment: Text.Center
                font.pixelSize: 30
                color: "#1c4b5a"
                text: qsTr("Lo primero al terminar")
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.Center
                font.pixelSize: 17
                lineHeight: 1.35
                text: qsTr("Cuando la computadora vuelva a encenderse, abre " +
                           "<b>«Preparar el centro»</b>.<br/><br/>" +
                           "Esa pantalla revisa la computadora entera y te dice, en una " +
                           "lista, qué falta por hacer. Cada renglón tiene su botón: no " +
                           "hay que escribir ningún comando.")
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            width: 640
            spacing: 24
            Text {
                width: parent.width
                horizontalAlignment: Text.Center
                font.pixelSize: 30
                color: "#1c4b5a"
                text: qsTr("La información se guarda sola")
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.Center
                font.pixelSize: 17
                lineHeight: 1.35
                text: qsTr("Todas las madrugadas se hace una copia de los datos del " +
                           "centro: al disco de la computadora, a un disco externo si " +
                           "está enchufado, y a la nube.<br/><br/>" +
                           "Y si un día la copia no se hace, <b>alguien se entera</b>. " +
                           "Un respaldo que falla en silencio es igual que no tenerlo.")
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            width: 640
            spacing: 24
            Text {
                width: parent.width
                horizontalAlignment: Text.Center
                font.pixelSize: 30
                color: "#1c4b5a"
                text: qsTr("Si algo no funciona")
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.Center
                font.pixelSize: 17
                lineHeight: 1.35
                text: qsTr("Hay un botón que se llama <b>«Algo no funciona»</b>.<br/><br/>" +
                           "Revisa las averías más comunes y arregla las que puede, ella " +
                           "sola. Antes de llamar a nadie, púlsalo: casi siempre basta " +
                           "con eso.")
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            width: 640
            spacing: 24
            Text {
                width: parent.width
                horizontalAlignment: Text.Center
                font.pixelSize: 30
                color: "#1c4b5a"
                text: qsTr("Los programas del Ministerio")
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.Center
                font.pixelSize: 17
                lineHeight: 1.35
                text: qsTr("SALMI, SOAPS y SNIS siguen siendo los de siempre y se abren " +
                           "igual que siempre. RedHornoma no los cambia: los protege.<br/><br/>" +
                           "Lo que cambia es que ahora varios puestos pueden usarlos a la " +
                           "vez, sobre la misma información.")
            }
        }
    }
}
