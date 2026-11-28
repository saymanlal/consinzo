import React from "react";
import { BRAND_MARK_PATH } from "./brand-mark-path";

export interface BrandMarkProps extends Omit<React.SVGProps<SVGSVGElement>, "children"> {
  /** Accessible name. Omit when the mark sits next to visible "CONSINZO" text. */
  title?: string;
}

/**
 * The CONSINZO mark as inline SVG. It inherits `currentColor`, so it follows the
 * surrounding text colour (dark on light surfaces, white on the IDE canvas).
 */
export function BrandMark({ title, className, ...props }: BrandMarkProps) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 512 512"
      fill="currentColor"
      className={className}
      role={title ? "img" : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : true}
      focusable="false"
      {...props}
    >
      <path fillRule="evenodd" d={BRAND_MARK_PATH} />
    </svg>
  );
}

/** Mark + wordmark lockup used in the navbar and footer. */
export function BrandLogo({
  className = "",
  markClassName = "h-7 w-7",
  wordmarkClassName = "text-sm",
}: {
  className?: string;
  markClassName?: string;
  wordmarkClassName?: string;
}) {
  return (
    <span className={`inline-flex items-center gap-2.5 font-semibold tracking-tight ${className}`}>
      <BrandMark className={`shrink-0 ${markClassName}`} />
      <span className={`uppercase tracking-wider ${wordmarkClassName}`}>CONSINZO</span>
    </span>
  );
}
