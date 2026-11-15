"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { ShareeApi, type AuthResult, type ShareeUser } from "@sharee/api-client";
import { API_URL } from "@/lib/sharee";

type AuthContextValue = {
  api: ShareeApi;
  user: ShareeUser | null;
  token: string | null;
  ready: boolean;
  signIn: (auth: AuthResult) => void;
  signOut: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);
const TOKEN_KEY = "sharee.web.token";
const USER_KEY = "sharee.web.user";

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(null);
  const [user, setUser] = useState<ShareeUser | null>(null);
  const [ready, setReady] = useState(false);

  const api = useMemo(() => {
    const client = new ShareeApi(API_URL);
    client.setToken(token ?? undefined);
    return client;
  }, [token]);

  useEffect(() => {
    const savedToken = localStorage.getItem(TOKEN_KEY);
    const savedUser = localStorage.getItem(USER_KEY);
    if (savedToken && savedUser) {
      setToken(savedToken);
      try {
        setUser(JSON.parse(savedUser) as ShareeUser);
      } catch {
        localStorage.removeItem(USER_KEY);
      }
    }
    setReady(true);
  }, []);

  useEffect(() => {
    if (!token) return;
    const client = new ShareeApi(API_URL, token);
    client
      .me()
      .then((me) => {
        setUser(me);
        localStorage.setItem(USER_KEY, JSON.stringify(me));
      })
      .catch(() => {
        /* token expired: keep cached user until next action */
      });
  }, [token]);

  const signIn = (auth: AuthResult) => {
    setToken(auth.accessToken);
    setUser(auth.user);
    localStorage.setItem(TOKEN_KEY, auth.accessToken);
    localStorage.setItem(USER_KEY, JSON.stringify(auth.user));
    if (auth.refreshToken) localStorage.setItem("sharee.web.refresh", auth.refreshToken);
  };

  const signOut = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem("sharee.web.refresh");
  };

  return (
    <AuthContext.Provider value={{ api, user, token, ready, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth must be used inside AuthProvider");
  return value;
}
