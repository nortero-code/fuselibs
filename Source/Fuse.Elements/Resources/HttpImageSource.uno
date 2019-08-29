using Uno;
using Uno.Graphics;
using Uno.Collections;
using Uno.UX;
using Uno.IO;
using Fuse.Drawing;
using Fuse.Resources.Exif;

using Experimental.TextureLoader;
using Experimental.Http;

namespace Fuse.Resources
{
	/** Provides an image fetched via HTTP which can be displayed by the @Image control.
	
		> *Note* @Image provides a shorthand for this, using its [Url](api:fuse/controls/image/url) property.

		## Example

			<Image>
				<HttpImageSource Url="https://upload.wikimedia.org/wikipedia/commons/0/06/Kitten_in_Rizal_Park%2C_Manila.jpg" />
			</Image>

		To cache the image to the disk, you can add `DiskCache` attribute and set it to `true` so that the next time we display an image it will no longer be downloaded from the network but use from disk instead.
	*/
	public sealed class HttpImageSource : ImageSource
	{
		/** The URL of the image.
		*/
		public String Url
		{
			get { return _proxy.Impl == null ? "" : (_proxy.Impl as HttpImageSourceImpl).Url; }
			set
			{
				_proxy.Release();
				if(value == null || value == "" )
					return;

				_proxy.Attach( HttpImageSourceCache.GetUrl( value, DiskCache ) );
			}
		}

		//ProxyImageSource composition
		ProxyImageSource _proxy;
		public HttpImageSource()
		{
			_proxy = new ProxyImageSource(this);
		}

		public HttpImageSource(String url)
		{
			_proxy = new ProxyImageSource(this);
			Url = url;
		}

		public MemoryPolicy DefaultPolicy { set { _proxy.DefaultSetPolicy(value); } }
		/** Specifies a hint for how the image should be managed in memory. See @MemoryPolicy. */
		public MemoryPolicy Policy { get { return _proxy.Policy; } set { _proxy.Policy = value; } }
		protected override void OnPinChanged() {  _proxy.OnPinChanged(); }

		public override ImageOrientation Orientation { get { return _proxy.Orientation; } }
		public override float2 Size { get { return _proxy.Size; } }
		public override int2 PixelSize { get { return _proxy.PixelSize; } }
		public override ImageSourceState State { get { return _proxy.State; } }
		public override texture2D GetTexture() { return _proxy.GetTexture(); }
		public override void Reload() { _proxy.Reload(); }
		public override float SizeDensity { get { return Density; } }

		//shared public interface
		/** Specifies the source's pixel density.
		*/
		public float Density { get { return _proxy.Density; } set { _proxy.Density = value; } }
		bool _diskCache = false;
		/** Determines whether we use the disk cache to store downloaded images so that the next time we display an image it will no longer be downloaded from the network. Default is false. */
		public bool DiskCache { get { return _diskCache; } set { _diskCache = value; } }

		public void ClearCache()
		{
			if (Url != "")
			{
				string filenameBase = HttpImageSourceCache.GetFilenameBase(Url);
				string filename = filenameBase + ".jpg";
				if (File.Exists(filename))
					File.Delete(filename);
				filename = filenameBase + ".png";
				if (File.Exists(filename))
					File.Delete(filename);
			}

		}
	}

	static class HttpImageSourceCache
	{
		static Dictionary<String,WeakReference<HttpImageSourceImpl>> _cache = new Dictionary<String,WeakReference<HttpImageSourceImpl>>();
		static public HttpImageSourceImpl GetUrl( String url, bool diskCache )
		{
			WeakReference<HttpImageSourceImpl> value = null;
			if( _cache.TryGetValue( url, out value ) )
			{
				HttpImageSourceImpl his;
				if( value.TryGetTarget( out his ) )
				{
					if (his.State == ImageSourceState.Failed)
						his.Reload();
					return his;
				}
				_cache.Remove( url );
			}

			var nv = new HttpImageSourceImpl( url, diskCache );
			_cache.Add( url, new WeakReference<HttpImageSourceImpl>(nv) );
			return nv;
		}

		static string GetCacheDirectory()
		{
			string path = Path.Combine(Directory.GetUserDirectory(UserDirectory.Data), "cached_images");
			if (!Directory.Exists(path))
				Directory.CreateDirectory(path);
			return path;
		}

		static public string GetFilenameBase(string url)
		{
			return Path.Combine(GetCacheDirectory(), url.GetHashCode().ToString());
		}
	}

	class HttpImageLoadClosure {
		int _numRedirects;
		Action<HttpResponseHeader, byte[], int> _done;
		Action<string> _fail;
		string _url;
		internal HttpImageLoadClosure(
			string url,
			Action<HttpResponseHeader, byte[], int> done,
			Action<string> fail,
			int numRedirects = 0) {
			_url = url;
			_numRedirects = numRedirects;
			_done = done;
			_fail = fail;
		}

		void HttpCallback(HttpResponseHeader response, byte[] data) {
			_done(response, data, _numRedirects);
		}

		public void run() {
			HttpLoader.LoadBinary(_url, HttpCallback, _fail);
		}
	}

	class HttpImageSourceImpl : LoadingImageSource
	{
		static readonly int MAX_REDIRECTS = 5;

		String _url;
		string _filenameBase;
		public String Url { get { return _url; } }
		String _contentType;
		bool _diskCache;

		public HttpImageSourceImpl( String url, bool diskCache )
		{
			_url = url;
			_diskCache = diskCache;
		}

		protected override void AttemptLoad()
		{
			try
			{
				_loading = true;
				if (IsFileCacheExist(out _filenameBase, out _contentType) && _diskCache)
				{
					new BackgroundLoad(null, _filenameBase, _contentType, _diskCache, SuccessCallback, FailureCallback);
				}
				else
				{
					var imageLoadClosure = new HttpImageLoadClosure(Url, HttpCallback, LoadFailed);
					imageLoadClosure.run();
				}
				OnChanged();
			}
			catch( Exception e )
			{
				Fail("Loading image from '" + Url + "' failed. " + e.Message, e);
			}
		}

		void SuccessCallback(texture2D texture, ImageOrientation orientation)
		{
			_loading = false;
			_orientation = orientation;
			SetTexture(texture);
		}

		void FailureCallback(Exception e)
		{
			_loading = false;
			Fail("Loading image from HTTP failed. " + e.Message, e);
		}

		ImageOrientation _orientation = ImageOrientation.Identity;
		public override ImageOrientation Orientation
		{
			get { return _orientation; }
		}

		int numberOfRedirects = 0;
		void HttpCallback(HttpResponseHeader response, byte[] data, int numRedirects)
		{
			if (response.StatusCode == 301) {
				if (numberOfRedirects > 5) {
					Fail("Failed to load HTTP Image due to too many redirects. ", null);
					return;
				}
				string location;
				response.Headers.TryGetValue("location", out location);
				if (location != null) {
					var imageLoadClosure = new HttpImageLoadClosure(location, HttpCallback, LoadFailed, numRedirects+1);
					imageLoadClosure.run();
				}
			}

			if (response.StatusCode != 200)
			{
				Fail("Loading image from HTTP failed with HTTP Status: " + response.StatusCode + " " +
					response.ReasonPhrase);
				return;
			}

			string ct;
			if (!response.Headers.TryGetValue("content-type",out ct))
				_contentType = "x-missing";
			else
				_contentType = ct;

			new BackgroundLoad(data, _filenameBase, _contentType, _diskCache, SuccessCallback, FailureCallback);
		}

		bool IsFileCacheExist(out string filenameBase, out string contentType)
		{
			filenameBase = HttpImageSourceCache.GetFilenameBase(Url);
			if (File.Exists(filenameBase + ".jpg"))
			{
				contentType = "image/jpg";
				return true;
			}
			if (File.Exists(filenameBase + ".png"))
			{
				contentType = "image/png";
				return true;
			}
			contentType = "";
			return false;
		}

		class BackgroundLoad
		{
			byte[] _data;
			string _contentType;
			string _filename;
			bool _diskCache;
			Action<texture2D, ImageOrientation> _done;
			Action<Exception> _fail;
			Exception _exception;
			ImageOrientation _orientation;
			texture2D _tex;

			public BackgroundLoad(byte[] data, string filenameBase, string contentType, bool diskCache, Action<texture2D, ImageOrientation> done, Action<Exception> fail)
			{
				_data = data;
				_contentType = contentType;
				_diskCache = diskCache;
				_done = done;
				_fail = fail;
				if (_contentType == "image/png")
					_filename = filenameBase + ".png";
				else
					_filename = filenameBase + ".jpg";
				GraphicsWorker.Dispatch(Run);
			}
			public void Run()
			{
				try
				{
					if (_data == null)
					{
						_data = File.ReadAllBytes(_filename);
						_tex = TextureLoader.ByteArrayToTexture2DFilename(_data, _filename);
					}
					else
					{
						_tex = TextureLoader.ByteArrayToTexture2DContentType(_data, _contentType);
						if (_diskCache)
							File.WriteAllBytes(_filename, _data);
					}
					_orientation = ExifData.FromByteArray(_data).Orientation;

					if defined(OpenGL)
						OpenGL.GL.Finish();

					UpdateManager.AddOnceAction(UIDoneCallback);
				}
				catch (Exception e)
				{
					_exception = e;
					UpdateManager.AddOnceAction(UIFailCallback);
				}
			}

			void UIDoneCallback()
			{
				_done(_tex, _orientation);
			}

			void UIFailCallback()
			{
				var e = _exception;
				_exception = null;
				_fail(e);
			}
		}

		void LoadFailed( string reason )
		{
			numberOfRedirects = 0;
			Fail("Loading image from '" + Url + "' failed: " + reason);
		}

		void Fail( string msg, Exception e = null )
		{
			Cleanup(CleanupReason.Failed);
			OnError(msg, e);
		}
	}
}
