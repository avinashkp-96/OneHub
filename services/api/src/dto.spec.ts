import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { LoginDto, RequestOtpDto, ResetPasswordDto } from './auth/dto/login.dto';
import { SignupCustomerDto } from './auth/dto/signup-customer.dto';
import { SignupProviderDto } from './auth/dto/signup-provider.dto';
import { PriceRangeDto } from './bids/dto/submit-bid.dto';
import { UpsertCategoryDto } from './categories/dto/upsert-category.dto';
import { UpsertSubServiceDto } from './categories/dto/upsert-sub-service.dto';
import { SubmitRatingDto } from './ratings/dto/submit-rating.dto';
import { PostRequirementDto } from './requirements/dto/post-requirement.dto';

type Ctor<T> = new () => T;

async function errorsFor<T extends object>(cls: Ctor<T>, body: object): Promise<string[]> {
  const errors = await validate(plainToInstance(cls, body));
  return errors.map((e) => e.property);
}

const customer = {
  fullName: 'Asha Rao',
  mobile: '9876543210',
  otp: '1234',
  password: 'secret1',
  confirmPassword: 'secret1',
  city: 'Kochi',
};

const provider = {
  fullNameOrBusinessName: 'Asha Electricals',
  mobile: '9876543210',
  otp: '1234',
  password: 'secret1',
  confirmPassword: 'secret1',
  categoryId: 'c1',
  subServiceIds: ['s1'],
  coverageRadiusKm: 5,
  latitude: 9.9,
  longitude: 76.3,
  idProofUrl: 'https://example.test/id.png',
};

describe('SignupCustomerDto', () => {
  it('accepts a complete body', async () => {
    expect(await errorsFor(SignupCustomerDto, customer)).toEqual([]);
  });

  it('rejects a mobile that is not 10 digits', async () => {
    expect(await errorsFor(SignupCustomerDto, { ...customer, mobile: '12345' })).toContain('mobile');
  });

  it('rejects a short password', async () => {
    expect(await errorsFor(SignupCustomerDto, { ...customer, password: '123' })).toContain('password');
  });

  it('rejects a malformed optional email but allows none', async () => {
    expect(await errorsFor(SignupCustomerDto, { ...customer, email: 'nope' })).toContain('email');
    expect(await errorsFor(SignupCustomerDto, customer)).not.toContain('email');
  });
});

describe('SignupProviderDto', () => {
  it('accepts a complete body', async () => {
    expect(await errorsFor(SignupProviderDto, provider)).toEqual([]);
  });

  it('requires an ID proof and coverage radius', async () => {
    const rest: Record<string, unknown> = { ...provider };
    delete rest.idProofUrl;
    delete rest.coverageRadiusKm;
    const errors = await errorsFor(SignupProviderDto, rest);
    expect(errors).toEqual(expect.arrayContaining(['idProofUrl', 'coverageRadiusKm']));
  });

  it('requires subServiceIds to be an array', async () => {
    expect(await errorsFor(SignupProviderDto, { ...provider, subServiceIds: 's1' })).toContain('subServiceIds');
  });
});

describe('login and reset DTOs', () => {
  it('LoginDto needs both fields', async () => {
    expect(await errorsFor(LoginDto, {})).toEqual(expect.arrayContaining(['mobileOrEmail', 'password']));
    expect(await errorsFor(LoginDto, { mobileOrEmail: 'a', password: 'b' })).toEqual([]);
  });

  it('RequestOtpDto needs a mobile', async () => {
    expect(await errorsFor(RequestOtpDto, {})).toContain('mobile');
  });

  it('ResetPasswordDto needs all four fields', async () => {
    const errors = await errorsFor(ResetPasswordDto, {});
    expect(errors).toEqual(
      expect.arrayContaining(['mobileOrEmail', 'otp', 'newPassword', 'confirmNewPassword']),
    );
  });
});

describe('PriceRangeDto', () => {
  it('accepts numbers and rejects strings', async () => {
    expect(await errorsFor(PriceRangeDto, { minPrice: 100, maxPrice: 200 })).toEqual([]);
    expect(await errorsFor(PriceRangeDto, { minPrice: '100', maxPrice: 200 })).toContain('minPrice');
  });
});

describe('PostRequirementDto', () => {
  const ok = { subServiceId: 's1', description: 'Fix', providerIds: ['p1'] };

  it('accepts a minimal body', async () => {
    expect(await errorsFor(PostRequirementDto, ok)).toEqual([]);
  });

  it('needs at least one provider', async () => {
    expect(await errorsFor(PostRequirementDto, { ...ok, providerIds: [] })).toContain('providerIds');
  });

  it('rejects a malformed preferred date', async () => {
    expect(await errorsFor(PostRequirementDto, { ...ok, preferredAt: 'tomorrow' })).toContain('preferredAt');
  });
});

describe('SubmitRatingDto', () => {
  const ok = { requirementId: 'r1', providerId: 'p1', stars: 4 };

  it('accepts 1 to 5 whole stars', async () => {
    expect(await errorsFor(SubmitRatingDto, ok)).toEqual([]);
  });

  it.each([0, 6, 3.5])('rejects %s stars', async (stars) => {
    expect(await errorsFor(SubmitRatingDto, { ...ok, stars })).toContain('stars');
  });
});

describe('category DTOs', () => {
  it('UpsertCategoryDto needs a name', async () => {
    expect(await errorsFor(UpsertCategoryDto, {})).toContain('name');
    expect(await errorsFor(UpsertCategoryDto, { name: 'Electrician', active: true })).toEqual([]);
  });

  it('UpsertSubServiceDto takes optional suggested prices', async () => {
    expect(await errorsFor(UpsertSubServiceDto, { name: 'Fan', suggestedMinPrice: 100 })).toEqual([]);
    expect(await errorsFor(UpsertSubServiceDto, { name: 'Fan', suggestedMinPrice: 'x' })).toContain(
      'suggestedMinPrice',
    );
  });
});
