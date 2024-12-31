import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock Blockchain Environment
class MockChain {
  private names: Record<string, any> = {};

  registerName(name: string, caller: string) {
    if (this.names[name]) {
      throw new Error("ERR_NAME_TAKEN");
    }
    this.names[name] = {
      owner: caller,
      expiresAt: Date.now() + 31536000 * 1000,
      locked: false,
      primaryAddress: null,
      records: [],
    };
    return true;
  }

  getNameInfo(name: string) {
    if (!this.names[name]) {
      throw new Error("ERR_NAME_NOT_FOUND");
    }
    return this.names[name];
  }

  renewName(name: string, caller: string) {
    const nameInfo = this.getNameInfo(name);
    if (nameInfo.owner !== caller) {
      throw new Error("ERR_UNAUTHORIZED");
    }
    nameInfo.expiresAt += 31536000 * 1000;
    return true;
  }

  lockName(name: string, caller: string) {
    const nameInfo = this.getNameInfo(name);
    if (nameInfo.owner !== caller) {
      throw new Error("ERR_UNAUTHORIZED");
    }
    nameInfo.locked = true;
    return true;
  }

  unlockName(name: string, caller: string) {
    const nameInfo = this.getNameInfo(name);
    if (nameInfo.owner !== caller) {
      throw new Error("ERR_UNAUTHORIZED");
    }
    nameInfo.locked = false;
    return true;
  }
}

// Tests
describe("Stacks Name Service (SNS)", () => {
  let chain: MockChain;
  let user1: string;
  let user2: string;

  beforeEach(() => {
    chain = new MockChain();
    user1 = "principal-user1";
    user2 = "principal-user2";
  });

  it("should register a new name", () => {
    const name = "example.stx";

    const result = chain.registerName(name, user1);
    expect(result).toBe(true);

    const nameInfo = chain.getNameInfo(name);
    expect(nameInfo).toMatchObject({
      owner: user1,
      locked: false,
      primaryAddress: null,
    });
  });

  it("should not register a name if it is taken", () => {
    const name = "example.stx";

    chain.registerName(name, user1);
    expect(() => chain.registerName(name, user2)).toThrowError("ERR_NAME_TAKEN");
  });

  it("should renew a name", () => {
    const name = "example.stx";
    chain.registerName(name, user1);

    const result = chain.renewName(name, user1);
    expect(result).toBe(true);
  });

  it("should not renew a name if unauthorized", () => {
    const name = "example.stx";
    chain.registerName(name, user1);

    expect(() => chain.renewName(name, user2)).toThrowError("ERR_UNAUTHORIZED");
  });

  it("should lock and unlock a name", () => {
    const name = "example.stx";
    chain.registerName(name, user1);

    const lockResult = chain.lockName(name, user1);
    expect(lockResult).toBe(true);

    const nameInfoAfterLock = chain.getNameInfo(name);
    expect(nameInfoAfterLock.locked).toBe(true);

    const unlockResult = chain.unlockName(name, user1);
    expect(unlockResult).toBe(true);

    const nameInfoAfterUnlock = chain.getNameInfo(name);
    expect(nameInfoAfterUnlock.locked).toBe(false);
  });

  it("should throw an error when trying to lock/unlock a name as a non-owner", () => {
    const name = "example.stx";
    chain.registerName(name, user1);

    expect(() => chain.lockName(name, user2)).toThrowError("ERR_UNAUTHORIZED");
    expect(() => chain.unlockName(name, user2)).toThrowError("ERR_UNAUTHORIZED");
  });
});
