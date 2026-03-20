import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { MovementEngine } from '../engine/movement_engine.js';
import { ChatManager } from './chat_manager.js';

const JWT_SECRET: string = process.env.JWT_SECRET || 'super_secret_dev_key';

export class SocketManager {
    private io: Server;
    private engine: MovementEngine;
    private static instance: SocketManager | null = null;

    constructor(server: any, engine: MovementEngine) {
        const allowedOrigins = process.env.NODE_ENV === 'production'
            ? ['https://wacting.com', 'https://www.wacting.com']
            : '*';
        this.io = new Server(server, {
            cors: { origin: allowedOrigins }
        });
        this.engine = engine;
        SocketManager.instance = this;
    }

    public init() {
        // WebSocket JWT authentication middleware
        this.io.use((socket, next) => {
            const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.replace('Bearer ', '');
            if (!token) {
                // Allow anonymous connections — map is publicly viewable
                socket.data.userId = null;
                return next();
            }
            try {
                const payload = jwt.verify(token, JWT_SECRET as jwt.Secret) as { userId: string };
                socket.data.userId = payload.userId;
                next();
            } catch {
                return next(new Error('Invalid token'));
            }
        });

        this.io.on('connection', (socket: Socket) => {
            console.log(`Client Connected: ${socket.id} (user: ${socket.data.userId || 'anonymous'})`);

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
        const sockets = this.io.sockets.sockets;
        if (sockets.size === 0) return;

        // Send all visible icons to every connected client
        const allIcons = Array.from(this.engine.icons.values()).filter((i: any) => i.size > 0);

        for (const [, socket] of sockets) {
            if (socket.data.viewport) {
                // Viewport-aware: spatially filtered for performance
                const { minX, minY, maxX, maxY } = socket.data.viewport;
                const nearby = this.engine.spatialIndex.search(minX, minY, maxX, maxY)
                    .filter((i: any) => i.size > 0);
                socket.volatile.emit('tick', nearby);
            } else {
                // No viewport set: send all icons (for initial load / anonymous users)
                socket.volatile.emit('tick', allIcons);
            }
        }
    }

    static notifyUser(userId: string, notification: any) {
        const io = SocketManager.instance?.io;
        if (!io) return;
        for (const [, socket] of io.sockets.sockets) {
            if ((socket as any).data.userId === userId) {
                socket.emit('notification', notification);
            }
        }
    }
}
