/**
 * @format
 */

import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import App from '../App';

describe('App', () => {
  test('renders correctly', async () => {
    await ReactTestRenderer.act(() => {
      ReactTestRenderer.create(<App />);
    });
  });

  test('renders without crashing', async () => {
    let tree;
    await ReactTestRenderer.act(() => {
      tree = ReactTestRenderer.create(<App />);
    });
    expect(tree).toBeDefined();
  });

  test('matches snapshot', async () => {
    let tree;
    await ReactTestRenderer.act(() => {
      tree = ReactTestRenderer.create(<App />);
    });
    expect(tree?.toJSON()).toMatchSnapshot();
  });
});

describe('Math operations', () => {
  test('addition works correctly', () => {
    expect(2 + 2).toBe(4);
  });

  test('multiplication works correctly', () => {
    expect(5 * 2).toBe(10);
  });
});

describe('Array operations', () => {
  test('array push works', () => {
    const arr = [1, 2, 3];
    arr.push(4);
    expect(arr).toHaveLength(4);
    expect(arr[3]).toBe(4);
  });

  test('array filter works', () => {
    const numbers = [1, 2, 3, 4, 5];
    const evens = numbers.filter(n => n % 2 === 0);
    expect(evens).toEqual([2, 4]);
  });
});
