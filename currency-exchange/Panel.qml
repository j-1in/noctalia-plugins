import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "CurrencyData.js" as CurrencyData

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 420 * Style.uiScaleRatio
  property real contentPreferredHeight: 280 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  anchors.fill: parent

  readonly property var main: pluginApi?.mainInstance

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string fromCurrency: cfg.sourceCurrency || defaults.sourceCurrency
  property string toCurrency: cfg.targetCurrency || defaults.targetCurrency
  property real fromAmount: 1.0

  readonly property bool loading: main?.loading || false
  readonly property bool loaded: main?.loaded || false
  readonly property real toAmount: main ? main.convert(fromAmount, fromCurrency, toCurrency) : 0
  readonly property real rate: main ? main.getRate(fromCurrency, toCurrency) : 0

  property var currencyModel: CurrencyData.buildCompactModel()

  ListModel {
    id: currencyListModel
    Component.onCompleted: {
      for (var i = 0; i < CurrencyData.currencies.length; i++) {
        var code = CurrencyData.currencies[i];
        append({ "key": code, "name": code });
      }
    }
  }

  function swapCurrencies() {
    var temp = fromCurrency;
    fromCurrency = toCurrency;
    toCurrency = temp;
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + (Style.marginXL)

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "currency-dollar"
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
          }

          NText {
            text: "Currency Converter"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "refresh"
            tooltipText: "Refresh rates"
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (main) main.fetchRates(true);
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: "Close"
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              if (pluginApi) pluginApi.withCurrentScreen((s) => pluginApi.closePanel(s))
            }
          }
        }
      }

      // Converter Form
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          // Row 1: From input + From combo
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Rectangle {
              id: fromInputRect
              Layout.fillWidth: true
              Layout.preferredWidth: 100
              Layout.preferredHeight: Style.baseWidgetSize
              color: Color.mSurfaceVariant
              border.color: fromInput.activeFocus ? Color.mPrimary : Color.mOutline
              border.width: fromInput.activeFocus ? 2 : Style.borderS
              radius: Style.iRadiusM

              TextInput {
                id: fromInput
                anchors.fill: parent
                anchors.leftMargin: Style.marginL
                anchors.rightMargin: Style.marginL
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                color: Color.mOnSurface
                font.pointSize: Style.fontSizeM
                font.weight: Font.Medium
                selectByMouse: true
                text: fromAmount.toString()

                validator: RegularExpressionValidator {
                  regularExpression: /^\d*[.,]?\d{0,2}$/
                }

                onTextChanged: {
                  var normalized = text.replace(",", ".");
                  var val = parseFloat(normalized);
                  if (!isNaN(val) && val >= 0) {
                    fromAmount = val;
                  }
                }
              }
            }

            CurrencyComboBox {
              id: fromCombo
              Layout.fillWidth: true
              Layout.preferredWidth: 100
              minimumWidth: 100
              model: currencyListModel
              currentKey: fromCurrency
              onSelected: key => {
                fromCurrency = key;
              }
            }
          }

          // Swap row
          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.baseWidgetSize * 0.8
            spacing: Style.marginS

            Item { Layout.fillWidth: true }

            NIconButton {
              icon: "arrows-exchange"
              tooltipText: "Swap currencies"
              baseSize: Style.baseWidgetSize * 0.7
              onClicked: swapCurrencies()
            }

            Item { Layout.fillWidth: true }
          }

          // Row 2: To input (result) + To combo
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Rectangle {
              id: toInputRect
              Layout.fillWidth: true
              Layout.preferredWidth: 100
              Layout.preferredHeight: Style.baseWidgetSize
              color: Color.mPrimary
              radius: Style.iRadiusM

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginL
                anchors.rightMargin: Style.marginS
                spacing: Style.marginXS

                NText {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignRight
                  text: loaded ? toAmount.toFixed(2) : (loading ? "..." : "--")
                  color: Color.mOnPrimary
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                }

                NIconButton {
                  id: copyBtn
                  Layout.alignment: Qt.AlignVCenter
                  icon: "copy"
                  tooltipText: "Copy result"
                  baseSize: Style.baseWidgetSize * 0.7
                  visible: loaded && toAmount > 0
                  onClicked: main.copyToClipboard(toAmount.toFixed(2))
                }
              }
            }

            CurrencyComboBox {
              id: toCombo
              Layout.fillWidth: true
              Layout.preferredWidth: 100
              minimumWidth: 100
              model: currencyListModel
              currentKey: toCurrency
              onSelected: key => {
                toCurrency = key;
              }
            }
          }

          Item { Layout.fillHeight: true }

          // Rate info
          NText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            text: {
              if (loading) return "Loading rates...";
              if (!loaded) return "Could not load rates";
              return "1 " + fromCurrency + " = " + main?.formatNumber(rate) + " " + toCurrency;
            }
          }

          // Last update time
          NText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: Color.mOnSurfaceVariant
            opacity: 0.6
            pointSize: Style.fontSizeXS
            visible: loaded && main?.lastFetch > 0
            text: {
              if (!main?.lastFetch) return "";
              var date = new Date(main.lastFetch);
              return "Updated " + date.toLocaleTimeString(Qt.locale(), "HH:mm");
            }
          }
        }
      }

    }
  }

  Component.onCompleted: {
    if (main) {
      main.fetchRates();
    }
  }
}
