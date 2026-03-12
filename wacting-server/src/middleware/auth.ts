import { FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';

const JWT_SECRET: string = process.env.JWT_SECRET || 'super_secret_dev_key';

export async function authenticateToken(request: FastifyRequest, reply: FastifyReply) {
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return reply.code(401).send({ error: 'Missing or invalid authorization header' });
    }

    const token = authHeader.split(' ')[1]!;
    try {
        const payload = jwt.verify(token, JWT_SECRET as jwt.Secret) as unknown as { userId: string };
        (request as any).user = { id: payload.userId };
    } catch {
        return reply.code(401).send({ error: 'Invalid or expired token' });
    }
}
