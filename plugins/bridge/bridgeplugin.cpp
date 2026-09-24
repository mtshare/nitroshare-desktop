/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2018 Nathan Osman
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include <QVariantList>
#include <QVariantMap>

#include <nitroshare/actionregistry.h>
#include <nitroshare/application.h>
#include <nitroshare/setting.h>
#include <nitroshare/settingsregistry.h>
#include <nitroshare/transfer.h>
#include <nitroshare/transfermodel.h>

#include "bridgeplugin.h"
#include "functionaction.h"

// Dynamic property used to give each transfer an ID that survives dismissals
const char *TransferIdProperty = "bridgeTransferId";

void BridgePlugin::initialize(Application *application)
{
    mActions.append(new FunctionAction(
        "status",
        tr("Retrieve the version, device name and UUID of this instance."),
        [application](const QVariantMap &) -> QVariant {
            return QVariantMap{
                { "version", application->version() },
                { "deviceName", application->deviceName() },
                { "deviceUuid", application->deviceUuid() }
            };
        }
    ));

    mActions.append(new FunctionAction(
        "transferlist",
        tr("Retrieve all transfers, including ones that have finished."),
        [this, application](const QVariantMap &) -> QVariant {
            QVariantList transfers;
            TransferModel *model = application->transferModel();
            for (int i = 0; i < model->rowCount(); ++i) {
                Transfer *transfer = model->data(model->index(i), Qt::UserRole).value<Transfer*>();
                transfers.append(QVariantMap{
                    { "id", transferId(transfer) },
                    { "direction", transfer->direction() == Transfer::Send ? "send" : "receive" },
                    { "state", QVariantList{ "connecting", "inProgress", "failed", "succeeded" }.value(transfer->state()) },
                    { "progress", transfer->progress() },
                    { "speed", transfer->speed() },
                    { "bytesRemaining", transfer->bytesRemaining() },
                    { "deviceName", transfer->deviceName() },
                    { "error", transfer->error() }
                });
            }
            return transfers;
        }
    ));

    mActions.append(new FunctionAction(
        "transfercancel",
        tr("Cancel the transfer with the specified \"id\"."),
        [this, application](const QVariantMap &params) -> QVariant {
            int index = findTransfer(application, params);
            if (index == -1) {
                return false;
            }
            TransferModel *model = application->transferModel();
            model->data(model->index(index), Qt::UserRole).value<Transfer*>()->cancel();
            return true;
        }
    ));

    mActions.append(new FunctionAction(
        "transferdismiss",
        tr("Remove the finished transfer with the specified \"id\"."),
        [this, application](const QVariantMap &params) -> QVariant {
            int index = findTransfer(application, params);
            if (index == -1) {
                return false;
            }
            application->transferModel()->dismiss(index);
            return true;
        }
    ));

    mActions.append(new FunctionAction(
        "transferclear",
        tr("Remove all finished transfers."),
        [application](const QVariantMap &) -> QVariant {
            application->transferModel()->dismissAll();
            return true;
        }
    ));

    mActions.append(new FunctionAction(
        "settinglist",
        tr("Retrieve all visible settings along with their current values."),
        [application](const QVariantMap &) -> QVariant {
            QVariantList settings;
            SettingsRegistry *registry = application->settingsRegistry();
            foreach (Setting *setting, registry->settings()) {
                if (setting->isHidden()) {
                    continue;
                }
                settings.append(QVariantMap{
                    { "name", setting->name() },
                    { "title", setting->title() },
                    { "type", static_cast<int>(setting->type()) },
                    { "category", setting->category() },
                    { "value", registry->value(setting->name()) }
                });
            }
            return settings;
        }
    ));

    mActions.append(new FunctionAction(
        "settingset",
        tr("Set the setting with the specified \"name\" to \"value\"."),
        [application](const QVariantMap &params) -> QVariant {
            SettingsRegistry *registry = application->settingsRegistry();
            Setting *setting = registry->findSetting(params.value("name").toString());
            if (!setting) {
                return false;
            }

            // JSON numbers arrive as doubles, so coerce to the setting's type
            QVariant value = params.value("value");
            switch (setting->type()) {
            case Setting::Integer:
                value = value.toInt();
                break;
            case Setting::Boolean:
                value = value.toBool();
                break;
            case Setting::StringList:
                value = value.toStringList();
                break;
            default:
                value = value.toString();
                break;
            }
            registry->setValue(setting->name(), value);
            return true;
        }
    ));

    foreach (Action *action, mActions) {
        application->actionRegistry()->add(action);
    }
}

void BridgePlugin::cleanup(Application *application)
{
    foreach (Action *action, mActions) {
        application->actionRegistry()->remove(action);
    }
    qDeleteAll(mActions);
    mActions.clear();
}

int BridgePlugin::findTransfer(Application *application, const QVariantMap &params) const
{
    QString id = params.value("id").toString();
    TransferModel *model = application->transferModel();
    for (int i = 0; i < model->rowCount(); ++i) {
        Transfer *transfer = model->data(model->index(i), Qt::UserRole).value<Transfer*>();
        if (transfer->property(TransferIdProperty).toString() == id) {
            return i;
        }
    }
    return -1;
}

QString BridgePlugin::transferId(Transfer *transfer)
{
    QVariant id = transfer->property(TransferIdProperty);
    if (!id.isValid()) {
        id = QString::number(mNextTransferId++);
        transfer->setProperty(TransferIdProperty, id);
    }
    return id.toString();
}
