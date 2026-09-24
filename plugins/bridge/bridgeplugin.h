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

#ifndef BRIDGEPLUGIN_H
#define BRIDGEPLUGIN_H

#include <QList>

#include <nitroshare/iplugin.h>

class Action;
class Transfer;

/**
 * @brief Actions that let a native frontend drive the application via the API
 *
 * The Qt widget plugins access the models directly; frontends running in a
 * separate process (such as the SwiftUI app on macOS) use these instead.
 */
class Q_DECL_EXPORT BridgePlugin : public IPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID Plugin_iid FILE "bridge.json")

public:

    virtual void initialize(Application *application);
    virtual void cleanup(Application *application);

private:

    int findTransfer(Application *application, const QVariantMap &params) const;
    QString transferId(Transfer *transfer);

    QList<Action*> mActions;
    quint64 mNextTransferId = 1;
};

#endif // BRIDGEPLUGIN_H
