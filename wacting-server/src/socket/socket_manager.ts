import { Server, Socket } from 'socket.io';
import { MovementEngine } from '../engine/movement_engine.js';
import { ChatManager } from './chat_manager.js';

export class SocketManager {
    private io: Server;
    private engine: MovementEngine;

    constructor(server: any, engine: MovementEngine) {
        this.io = new Server(server, {
            cors: { origin: '*' } // TODO: Restrict to Wacting.com in Phase 7 production
        });
        this.engine = engine;
    }

    public init() {
        this.io.on('connection', (socket: Socket) => {
            console.log(`Client Connected: ${socket.id}`);

            const chatManager = new ChatManager(this.io);
            chatManager.handleConnection(socket);

            socket.on('join_viewport', (data: { minX: number, minY: number, maxX: number, maxY: number }) => {
                // In a heavily populated room, clients send their map viewport constantly.
                // We link this client to that specific region so we don't spam them with all 510,000 icons.
                socket.data.viewport = data;

                // Optionally, join regional rooms here instead of per-client emitting
            });

            socket.on('updateRestrictedBounds', (data: { countries: string[] }) => {
                console.log(`Client ${socket.id} restricted bounds to:`, data.countries);
                // The client is using a mock ID prefixed by "mock-" if it's not a real user, but we'll try to find
                // the icon by socket ID or assume some user mapping here. For now, since icons are loaded globally:
                // Find any icon matching this user/socket and apply. 
                // Since this is MVP, we assume 1 connection = 1 icon for testing if we had auth linked.
                // Since we simulate 5000 icons, if the user controls one, we'd update `engine.icons.get(myIconId).restrictedCountries = data.countries`
            });

            socket.on('disconnect', () => {
                console.log(`Client Disconnected: ${socket.id}`);
            });
        });

        // Start broadcasting loop at 1 Hz (matches engine tick)
        setInterval(() => this.broadcastViewportUpdates(), 1000);
    }

    private broadcastViewportUpdates() {
        // For every connected client, fetch icons that reside only in their screen bounds from the SpatialIndex
        const sockets = this.io.sockets.sockets;

        for (const [id, socket] of sockets) {
            if (socket.data.viewport) {
                const { minX, minY, maxX, maxY } = socket.data.viewport;

                // RBush fast spatial query! O(log N) instead of O(N). Extremely crucial for scalability.
                let nearbyIcons = this.engine.spatialIndex.search(minX, minY, maxX, maxY);

                // Token Mechanics: If a user gives away all tokens, they disappear from the map.
                nearbyIcons = nearbyIcons.filter((i: any) => i.tokens && i.tokens > 0);

                // Emit just the subset
                socket.volatile.emit('tick', nearbyIcons);
            }
        }
    }
}
