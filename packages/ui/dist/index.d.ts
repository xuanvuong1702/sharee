import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from "react";

export declare function Container(props: { children: ReactNode; wide?: boolean }): ReactNode;
export declare function Button(
  props: ButtonHTMLAttributes<HTMLButtonElement> & {
    children?: ReactNode;
    variant?: "primary" | "secondary" | "ghost" | "danger";
    size?: "sm" | "md" | "lg";
  },
): ReactNode;
export declare function Card(props: {
  children: ReactNode;
  className?: string;
  padded?: boolean;
}): ReactNode;
export declare function Badge(props: {
  children: ReactNode;
  tone?: "blue" | "green" | "amber" | "red" | "gray";
}): ReactNode;
export declare function Field(
  props: InputHTMLAttributes<HTMLInputElement> & { label: string; hint?: string },
): ReactNode;
export declare function Logo(props: { light?: boolean }): ReactNode;
export declare function SectionTitle(props: {
  eyebrow?: string;
  title: string;
  action?: ReactNode;
}): ReactNode;
export declare function EmptyState(props: { title: string; message: string }): ReactNode;
