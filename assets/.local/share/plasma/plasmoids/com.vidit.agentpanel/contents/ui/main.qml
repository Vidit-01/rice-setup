import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    compactRepresentation: CompactRepresentation { app: root }
    fullRepresentation: FullRepresentation { app: root }

    property var agents: ({ "running": [], "waiting": [], "finished": [], "attention": 0, "featured": null })
    property string agentsSignature: ""
    property bool refreshing: false
    property string launchError: ""

    function sessionSignature(items) {
        return items.map(agent => [
            agent.id, agent.name, agent.summary, agent.project, agent.projectPath,
            agent.provider, agent.status, agent.active, agent.needsInput,
            agent.completedTurn, agent.completedAt, agent.attention, agent.opened,
            agent.canOpen, agent.canDelete, agent.active ? 0 : agent.updated
        ]);
    }

    function signatureFor(data) {
        const featured = data.featured;
        return JSON.stringify({
            running: sessionSignature(data.running || []),
            waiting: sessionSignature(data.waiting || []),
            finished: sessionSignature(data.finished || []),
            attention: data.attention || 0,
            featured: featured ? [featured.id, featured.displayStatus, featured.name, featured.summary, featured.project, featured.provider] : null
        });
    }

    function refresh() {
        if (refreshing) return;
        refreshing = true;
        source.exec("python3 \"$HOME/.local/share/plasma/plasmoids/com.vidit.agentpanel/contents/code/agents.py\"", function(out, code, err) {
            try {
                if (code !== 0) throw new Error((err || out || "Session scan failed").trim());
                const next = JSON.parse(out);
                const nextSignature = signatureFor(next);
                if (nextSignature !== agentsSignature) {
                    agents = next;
                    agentsSignature = nextSignature;
                }
                launchError = "";
            } catch (error) {
                launchError = error.message || "Could not update agent sessions";
            }
            refreshing = false;
        });
    }

    function openSession(agent) {
        launchError = "";
        const command = "/usr/bin/python3 \"$HOME/.local/share/plasma/plasmoids/com.vidit.agentpanel/contents/code/open_session.py\" "
            + shellQuote(agent.provider) + " " + shellQuote(agent.id) + " " + shellQuote(agent.projectPath || "");
        source.exec(command, function(out, code, err) {
            if (code !== 0) launchError = (err || out || "Could not open the agent session").trim();
            refresh();
        });
    }

    function deleteSession(id) {
        launchError = "";
        source.exec("/usr/bin/python3 \"$HOME/.local/share/plasma/plasmoids/com.vidit.agentpanel/contents/code/session_actions.py\" delete " + id, function(out, code, err) {
            if (code !== 0) launchError = (err || out || "Could not delete the chat").trim();
            refresh();
        });
    }

    function closeSession(agent) {
        launchError = "";
        const command = "/usr/bin/python3 \"$HOME/.local/share/plasma/plasmoids/com.vidit.agentpanel/contents/code/session_actions.py\" close "
            + shellQuote(agent.provider) + " " + shellQuote(agent.id);
        source.exec(command, function(out, code, err) {
            if (code !== 0) launchError = (err || out || "Could not close the chat window").trim();
            refresh();
        });
    }

    function acknowledgeAllDone() {
        source.exec("python3 \"$HOME/.local/share/plasma/plasmoids/com.vidit.agentpanel/contents/code/agents.py\" acknowledge-all", function() {
            refresh();
        });
    }

    function shellQuote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'";
    }

    function openNewChat(projectPath) {
        launchError = "";
        source.exec("/usr/bin/python3 \"$HOME/.local/share/plasma/plasmoids/com.vidit.agentpanel/contents/code/new_chat.py\" " + shellQuote(projectPath), function(out, code, err) {
            if (code !== 0) launchError = (err || out || "Could not open a new chat").trim();
        });
    }

    Plasma5Support.DataSource {
        id: source
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})
        property int serial: 0
        function exec(command, callback) {
            const key = command + " #agentpanel" + (++serial);
            if (callback) callbacks[key] = callback;
            connectSource(key);
        }
        onNewData: (key, data) => {
            const cb = callbacks[key];
            delete callbacks[key];
            disconnectSource(key);
            if (cb) cb(data.stdout || "", data["exit code"], data.stderr || "");
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
