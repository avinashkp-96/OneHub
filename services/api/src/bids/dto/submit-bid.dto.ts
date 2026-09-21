import { IsNumber } from 'class-validator';

// docx 5.4 — Initial and refined price range share the same shape.
export class PriceRangeDto {
  @IsNumber()
  minPrice: number;

  @IsNumber()
  maxPrice: number;
}
