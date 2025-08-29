using System;
using System.Collections.Generic;
using System.Collections.Concurrent;

namespace PraxisWpf.Services
{
    public enum ServiceLifetime
    {
        Transient,    // New instance every time
        Singleton,    // Same instance always
        Scoped        // Same instance within a scope (not implemented for WPF)
    }

    public class ServiceDescriptor
    {
        public Type ServiceType { get; set; } = null!;
        public Type? ImplementationType { get; set; }
        public object? Instance { get; set; }
        public Func<DIContainer, object>? Factory { get; set; }
        public ServiceLifetime Lifetime { get; set; }
    }

    public class DIContainer
    {
        private readonly ConcurrentDictionary<Type, ServiceDescriptor> _services = new();
        private readonly ConcurrentDictionary<Type, object> _singletons = new();
        private readonly object _lock = new();

        public static DIContainer Instance { get; } = new DIContainer();

        private DIContainer() { }

        #region Registration Methods

        public DIContainer RegisterTransient<TInterface, TImplementation>()
            where TInterface : class
            where TImplementation : class, TInterface, new()
        {
            return RegisterTransient<TInterface>(() => new TImplementation());
        }

        public DIContainer RegisterTransient<TInterface>(Func<DIContainer, TInterface> factory)
            where TInterface : class
        {
            _services[typeof(TInterface)] = new ServiceDescriptor
            {
                ServiceType = typeof(TInterface),
                Factory = container => factory(container),
                Lifetime = ServiceLifetime.Transient
            };

            Logger.Debug("DIContainer", $"Registered transient: {typeof(TInterface).Name}");
            return this;
        }

        public DIContainer RegisterSingleton<TInterface, TImplementation>()
            where TInterface : class
            where TImplementation : class, TInterface, new()
        {
            return RegisterSingleton<TInterface>(() => new TImplementation());
        }

        public DIContainer RegisterSingleton<TInterface>(Func<DIContainer, TInterface> factory)
            where TInterface : class
        {
            _services[typeof(TInterface)] = new ServiceDescriptor
            {
                ServiceType = typeof(TInterface),
                Factory = container => factory(container),
                Lifetime = ServiceLifetime.Singleton
            };

            Logger.Debug("DIContainer", $"Registered singleton: {typeof(TInterface).Name}");
            return this;
        }

        public DIContainer RegisterSingleton<TInterface>(TInterface instance)
            where TInterface : class
        {
            _services[typeof(TInterface)] = new ServiceDescriptor
            {
                ServiceType = typeof(TInterface),
                Instance = instance,
                Lifetime = ServiceLifetime.Singleton
            };

            _singletons[typeof(TInterface)] = instance;
            Logger.Debug("DIContainer", $"Registered singleton instance: {typeof(TInterface).Name}");
            return this;
        }

        #endregion

        #region Resolution Methods

        public T Resolve<T>() where T : class
        {
            return (T)Resolve(typeof(T));
        }

        public object Resolve(Type serviceType)
        {
            if (!_services.TryGetValue(serviceType, out var descriptor))
            {
                throw new InvalidOperationException($"Service of type {serviceType.Name} is not registered");
            }

            return descriptor.Lifetime switch
            {
                ServiceLifetime.Transient => CreateInstance(descriptor),
                ServiceLifetime.Singleton => GetOrCreateSingleton(descriptor),
                _ => throw new ArgumentOutOfRangeException()
            };
        }

        public T? TryResolve<T>() where T : class
        {
            try
            {
                return Resolve<T>();
            }
            catch
            {
                return null;
            }
        }

        public bool IsRegistered<T>() where T : class
        {
            return _services.ContainsKey(typeof(T));
        }

        public bool IsRegistered(Type serviceType)
        {
            return _services.ContainsKey(serviceType);
        }

        #endregion

        #region Private Methods

        private object CreateInstance(ServiceDescriptor descriptor)
        {
            if (descriptor.Instance != null)
            {
                return descriptor.Instance;
            }

            if (descriptor.Factory != null)
            {
                try
                {
                    return descriptor.Factory(this);
                }
                catch (Exception ex)
                {
                    Logger.Error("DIContainer", $"Failed to create instance of {descriptor.ServiceType.Name}", ex);
                    throw;
                }
            }

            if (descriptor.ImplementationType != null)
            {
                try
                {
                    return CreateInstanceWithConstructorInjection(descriptor.ImplementationType);
                }
                catch (Exception ex)
                {
                    Logger.Error("DIContainer", $"Failed to create instance of {descriptor.ImplementationType.Name}", ex);
                    throw;
                }
            }

            throw new InvalidOperationException($"Unable to create instance of {descriptor.ServiceType.Name}");
        }

        private object GetOrCreateSingleton(ServiceDescriptor descriptor)
        {
            if (_singletons.TryGetValue(descriptor.ServiceType, out var singleton))
            {
                return singleton;
            }

            lock (_lock)
            {
                if (_singletons.TryGetValue(descriptor.ServiceType, out singleton))
                {
                    return singleton;
                }

                singleton = CreateInstance(descriptor);
                _singletons[descriptor.ServiceType] = singleton;
                return singleton;
            }
        }

        private object CreateInstanceWithConstructorInjection(Type implementationType)
        {
            var constructors = implementationType.GetConstructors();
            var constructor = constructors[0]; // Use first constructor for simplicity

            var parameters = constructor.GetParameters();
            var args = new object[parameters.Length];

            for (int i = 0; i < parameters.Length; i++)
            {
                var parameterType = parameters[i].ParameterType;
                if (IsRegistered(parameterType))
                {
                    args[i] = Resolve(parameterType);
                }
                else
                {
                    throw new InvalidOperationException($"Cannot resolve parameter {parameterType.Name} for {implementationType.Name}");
                }
            }

            return Activator.CreateInstance(implementationType, args)!;
        }

        #endregion

        #region Utility Methods

        public void Clear()
        {
            _services.Clear();
            _singletons.Clear();
            Logger.Debug("DIContainer", "Container cleared");
        }

        public IEnumerable<Type> GetRegisteredServices()
        {
            return _services.Keys;
        }

        public void LogRegisteredServices()
        {
            Logger.Info("DIContainer", $"Registered services: {_services.Count}");
            foreach (var service in _services.Keys)
            {
                var descriptor = _services[service];
                Logger.Debug("DIContainer", $"  {service.Name} ({descriptor.Lifetime})");
            }
        }

        #endregion
    }

    // Extension methods for easier registration
    public static class DIContainerExtensions
    {
        public static DIContainer AddTransient<TInterface, TImplementation>(this DIContainer container)
            where TInterface : class
            where TImplementation : class, TInterface, new()
        {
            return container.RegisterTransient<TInterface, TImplementation>();
        }

        public static DIContainer AddSingleton<TInterface, TImplementation>(this DIContainer container)
            where TInterface : class
            where TImplementation : class, TInterface, new()
        {
            return container.RegisterSingleton<TInterface, TImplementation>();
        }

        public static DIContainer AddSingleton<TInterface>(this DIContainer container, TInterface instance)
            where TInterface : class
        {
            return container.RegisterSingleton(instance);
        }
    }
}