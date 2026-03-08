import { Server, Socket } from 'socket.io';

export class ChatManager {
    constructor(private io: Server) { }

    public handleConnection(socket: Socket) {

        // Users can join specific Alliance rooms to chat privately
        socket.on('join_alliance', (allianceId: string) => {
            const roomName = `alliance_${allianceId}`;
            socket.join(roomName);
            socket.emit('system_message', `You joined alliance: ${allianceId}`);
        });

        // Leave an alliance room
        socket.on('leave_alliance', (allianceId: string) => {
            const roomName = `alliance_${allianceId}`;
            socket.leave(roomName);
        });

        // Global World Chat Broadcast
        socket.on('send_global_msg', (data: { sender: string, text: string }) => {
            // Emits to EVERYONE connected to the server
            // In a production app with millions, you'd rate-limit this
            this.io.emit('receive_global_msg', {
                sender: data.sender,
                text: data.text,
                timestamp: Date.now()
            });
        });

        // Private Alliance Chat Broadcast
        socket.on('send_alliance_msg', (data: { allianceId: string, sender: string, text: string }) => {
            const roomName = `alliance_${data.allianceId}`;
            // Emits ONLY to sockets that called socket.join(roomName)
            this.io.to(roomName).emit('receive_alliance_msg', {
                sender: data.sender,
                text: data.text,
                timestamp: Date.now()
            });
        });
    }
}
