module farbfeld;

private
{
	import std.algorithm;
	import std.conv;
	import std.math;
	import std.stdio;
	import std.string;
	
	template addProperty(T, string propertyName, string defaultValue = T.init.to!string)
	{	 
		const char[] addProperty = format(
			`
			private %2$s %1$s = %4$s;
	 
			void set%3$s(%2$s %1$s)
			{
				this.%1$s = %1$s;
			}
	 
			%2$s get%3$s()
			{
				return %1$s;
			}
			`,
			"_" ~ propertyName.toLower,
			T.stringof,
			propertyName,
			defaultValue
			);
	}
	
	enum BYTE_ORDER
	{
		LITTLE_ENDIAN,
		BIG_ENDIAN
	}
	
	T buildFromBytes(T)(BYTE_ORDER byteOrder, ubyte[] bytes...)
	{
		T mask;
		size_t shift;
	
		foreach (i, e; bytes)
		{
			final switch (byteOrder) with (BYTE_ORDER)
			{
				case LITTLE_ENDIAN:
					shift = (i << 3);
					break;
				case BIG_ENDIAN:
					shift = ((bytes.length - i - 1) << 3);
					break;
			}
			mask |= (e << shift);
		}
	
		return mask;
	}
	
	auto buildFromValue(T)(BYTE_ORDER byteOrder, T value)
	{
		ubyte[] data;
		T mask = cast(T) 0xff;
		size_t shift;
		 
		foreach (i; 0..T.sizeof)
		{		
			final switch (byteOrder) with (BYTE_ORDER)
			{
				case LITTLE_ENDIAN:
					shift = (i << 3);
					break;
				case BIG_ENDIAN:
					shift = ((T.sizeof - i - 1) << 3);
					break;
			}
			
			data ~= cast(ubyte) (
				(value & (mask << shift)) >> shift
			);
		}
		 
		return data;
	}
}


class RGBAColor
{
	mixin(addProperty!(int, "R"));
	mixin(addProperty!(int, "G"));
	mixin(addProperty!(int, "B"));
	mixin(addProperty!(int, "A"));

	this(int R = 0, int G = 0, int B = 0, int A = 0)
	{
		this._r = R;
		this._g = G;
		this._b = B;
		this._a = A;
	}

	const float luminance709()
	{
	   return (_r  * 0.2126f + _g  * 0.7152f + _b  * 0.0722f);
	}
	
	const float luminance601()
	{
	   return (_r * 0.3f + _g * 0.59f + _b * 0.11f);
	}
	
	const float luminanceAverage()
	{
	   return (_r + _g + _b) / 3.0;
	}

	alias luminance = luminance709;

	override string toString()
	{		
		return format("RGBAColor(%d, %d, %d, %d, I = %f)", _r, _g, _b, _a, this.luminance);
	}

	RGBAColor opBinary(string op, T)(auto ref T rhs)
	{
		return mixin(
			format(`new RGBAColor( 
				clamp(cast(int) (_r  %1$s rhs), 0, 65535),
				clamp(cast(int) (_g  %1$s rhs), 0, 65535),
				clamp(cast(int) (_b  %1$s rhs), 0, 65535),
				clamp(cast(int) (_a  %1$s rhs), 0, 65535)
				)
			`,
			op
			)
		);
	}

	RGBAColor opBinary(string op)(RGBAColor rhs)
	{
		return mixin(
			format(`new RGBAColor( 
				clamp(cast(int) (_r  %1$s rhs.getR), 0, 65535),
				clamp(cast(int) (_g  %1$s rhs.getG), 0, 65535),
				clamp(cast(int) (_b  %1$s rhs.getB), 0, 65535),
				clamp(cast(int) (_a  %1$s rhs.getA), 0, 65535)
				)
			`,
			op
			)
		);
	}
}


class FarbfeldImage
{
	mixin(addProperty!(uint, "Width"));
	mixin(addProperty!(uint, "Height"));
	
	private
	{
		RGBAColor[] _image;

		auto actualIndex(size_t i)
		{
			auto S = _width * _height;
		
			return clamp(i, 0, S - 1);
		}

		auto actualIndex(size_t i, size_t j)
		{
			auto W = cast(size_t) clamp(i, 0, _width - 1);
			auto H = cast(size_t) clamp(j, 0, _height - 1);
			auto S = _width * _height;
		
			return clamp(W + H * _width, 0, S);
		}
	}

	this(uint width = 0, uint height = 0, RGBAColor color = new RGBAColor(0, 0, 0, 0))
	{
		this._width = width;
		this._height = height;

		foreach (x; 0.._width)
		{
			foreach (y; 0.._height)
			{
				_image ~= color;
			}	
		}
	}

	RGBAColor opIndexAssign(RGBAColor color, size_t x, size_t y)
	{
		_image[actualIndex(x, y)] = color;
		return color;
	}

	RGBAColor opIndexAssign(RGBAColor color, size_t x)
	{
		_image[actualIndex(x)] = color;
		return color;
	}

	RGBAColor opIndex(size_t x, size_t y)
	{
		return _image[actualIndex(x, y)];
	}

	RGBAColor opIndex(size_t x)
	{
		return _image[actualIndex(x)];
	}

	override string toString()
	{
		string accumulator = "[";

		foreach (x; 0.._width)
		{
			string tmp = "[";
			foreach (y; 0.._height)
			{
				tmp ~= _image[actualIndex(x, y)].toString ~ ", ";				
			}
			tmp = tmp[0..$-2] ~ "], ";
			accumulator ~= tmp;
		}
		return accumulator[0..$-2] ~ "]";
	}

	alias width = getWidth;
	alias height = getHeight;

	final RGBAColor[] array()
	{
		return _image;
	}
	
	final void array(RGBAColor[] image)
	{
		_image = image;
	}

	final void changeCapacity(uint x, uint y)
	{
		long newLength = (x * y);
		
		if (newLength > _image.length)
		{
			auto restLength = cast(long) newLength - _image.length;
			_image.length += cast(size_t) restLength;
		}
		else
		{
			if (newLength < _image.length)
			{
				auto restLength = cast(long) _image.length - newLength;
				_image.length -= cast(size_t) restLength;
			}
		}
		_width = x;
		_height = y;
	}
	
	
	void load(string filename)
	{
		File file;
		file.open(filename, `rb`);
		
		// magic number is `farbfeld` (field size: 8 bytes)
		auto magicNumber = new void[8];
		file.rawRead!void(magicNumber);
		// image width (field size: 4 bytes) and image height (field size: 4 bytes)
		auto imageSizes = new ubyte[8];
		file.rawRead!ubyte(imageSizes);
		
		_width = buildFromBytes!uint(BYTE_ORDER.BIG_ENDIAN, imageSizes[0..4]);
		_height = buildFromBytes!uint(BYTE_ORDER.BIG_ENDIAN, imageSizes[4..$]);
		_image = [];
		
		foreach (i; 0.._width)
		{
			foreach (j; 0.._height)
			{
				auto pixel = new ubyte[8];
				file.rawRead!ubyte(pixel);
				
				auto R = buildFromBytes!ushort(BYTE_ORDER.BIG_ENDIAN, pixel[0..2]);
				auto G = buildFromBytes!ushort(BYTE_ORDER.BIG_ENDIAN, pixel[2..4]);
				auto B = buildFromBytes!ushort(BYTE_ORDER.BIG_ENDIAN, pixel[4..6]);
				auto A = buildFromBytes!ushort(BYTE_ORDER.BIG_ENDIAN, pixel[6..$]);
				
				_image ~= new RGBAColor(R, G, B, A);
			}
		}
	}
	
	
	void save(string filename)
	{
		File file;
		file.open(filename, `wb`);
		
		// magic number
		file.write(`farbfeld`);
		//width
		file.write(cast(char[]) buildFromValue!uint(BYTE_ORDER.BIG_ENDIAN, _width));
		// height
		file.write(cast(char[]) buildFromValue!uint(BYTE_ORDER.BIG_ENDIAN, _height));
		
		foreach (i; 0..(_width * _height))
		{
			auto pixel = _image[i];
			
			auto R = buildFromValue!ushort(BYTE_ORDER.BIG_ENDIAN, cast(ushort) pixel.getR);
			auto G = buildFromValue!ushort(BYTE_ORDER.BIG_ENDIAN, cast(ushort) pixel.getG);
			auto B = buildFromValue!ushort(BYTE_ORDER.BIG_ENDIAN, cast(ushort) pixel.getB);
			auto A = buildFromValue!ushort(BYTE_ORDER.BIG_ENDIAN, cast(ushort) pixel.getA);
			
			file.write(cast(char[]) R);
			file.write(cast(char[]) G);
			file.write(cast(char[]) B);
			file.write(cast(char[]) A);
		}
	}
}
