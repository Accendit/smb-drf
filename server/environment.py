import gym
from gym import spaces

import server


class SuperMarioBrosEnvironment(gym.Env):

    def __init__(self) -> None:
        super().__init__()
        self.action_space = spaces.MultiDiscrete([5, 2, 2])
        self.observation_space = spaces.Box(low=0, high=3, shape=(12, 10), dtype='uint8') # TODO: Check this
        self.serve()

    def _response_to_output(self, r: dict):
        r = server.deserialize_packet(r)
        
        observation = r['view']
        reward = r['score']
        done = (    
            r['playerstate'] == 4   or  # Sliding down the pole
            r['playerstate'] == 11  or  # Dying animation
            r['viewport_y']  >= 2       # Fallen down hole
        )
        info = {}

        return observation, reward, done, info

    def serve(self) -> None:
        conn, addr = server.get_connection()

        self.conn = conn
        self.client_address = addr

    def reset(self):
        pkt = server.serialize_packet(dict(
            up = False,
            right = False,
            down = False,
            left = False,
            a = False,
            b = False,
            reset = True
        ))
        self.conn.send(pkt)
        r = self.conn.recv(255) # After sending we should receive a response
        observation, _, _, _ = self._response_to_output(r)
        return observation # Apparently `reset` should only return an observation 

    def step(self, action):
        assert self.action_space.contains(action), "%r (%s) invalid " % (
            action,
            type(action),
        )

        pkt = server.serialize_packet(dict(
            up = action[0] == 1,
            right = action[0] == 2,
            down = action[0] == 3,
            left = action[0] == 4,
            a = action[1] == 1,
            b = action[2] == 1,
            reset = False
        ))
        self.conn.send(pkt)
        r = self.conn.recv(255)
        
        return self._response_to_output(r)

    def close(self):
        self.conn.close()
        return
    

    def render(self, mode="human") -> None:
        return None



gym.register('SMB-v0', entry_point=SuperMarioBrosEnvironment)